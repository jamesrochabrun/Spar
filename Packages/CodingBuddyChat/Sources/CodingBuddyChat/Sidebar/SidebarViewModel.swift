//
//  SidebarViewModel.swift
//  CodingBuddyChat
//

import ClaudeCodeCore
import Foundation
import InterviewKit

@Observable @MainActor
public final class SidebarViewModel {

  // MARK: - Public State

  public private(set) var sessionRows: [AttemptRow] = []
  public var selectedSessionId: String?
  public var isSidebarVisible: Bool = true
  public var isNewSessionSheetPresented = false
  /// Mode the new-session sheet opens preselected to from the global "+".
  public private(set) var newSessionInitialMode: SessionMode = .mockInterview
  /// The global "+" leaves the mode picker available.
  public private(set) var isNewSessionModeSelectionLocked = false

  // MARK: - Callbacks

  public var onSessionSelected: ((StoredSession) -> Void)?
  public var onStartSession: ((ChatService.NewSessionRequest) -> Void)?
  public var onDeleteSession: ((StoredSession) -> Void)?
  public var onDashboardToggle: (() -> Void)?

  // MARK: - Private

  private let sessionStorage: SessionStorageProtocol
  private let interviewStorage: any InterviewStorageProtocol
  private var pendingNewSession: StoredSession?
  private var pendingNewSessionMode: SessionMode = .practice

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol,
    interviewStorage: any InterviewStorageProtocol
  ) {
    self.sessionStorage = sessionStorage
    self.interviewStorage = interviewStorage
  }

  // MARK: - Loading

  public func loadSessions() async {
    do {
      let sessions = try await sessionStorage.getAllSessions()
      let attempts = (try? await interviewStorage.attempts(limit: nil)) ?? []

      var questionTitlesById: [String: String] = [:]
      let questionIds = Set(attempts.compactMap(\.questionId))
      for questionId in questionIds {
        if let question = try? await interviewStorage.question(id: questionId) {
          questionTitlesById[questionId] = question.title
        }
      }

      var scoresByAttemptId: [String: Double] = [:]
      for attempt in attempts where attempt.status == .evaluated {
        if let evaluation = try? await interviewStorage.evaluation(forAttemptId: attempt.id) {
          scoresByAttemptId[attempt.id] = evaluation.overallScore
        }
      }

      let sessionsForDisplay = sessionsIncludingPendingNewSession(sessions)
      sessionRows = AttemptRow.rows(
        attempts: attemptsIncludingPendingPlaceholder(attempts),
        sessions: sessionsForDisplay,
        questionTitlesById: questionTitlesById,
        scoresByAttemptId: scoresByAttemptId
      )
    } catch {
      sessionRows = []
    }
  }

  // MARK: - Pending session (optimistic row)

  public func preparePendingNewSession(
    mode: SessionMode,
    provider: ChatProvider,
    workingDirectory: String?
  ) {
    let normalizedWorkingDirectory = Self.normalizedWorkingDirectory(workingDirectory)
    let now = Date()
    let session = StoredSession(
      id: UUID().uuidString.lowercased(),
      createdAt: now,
      firstUserMessage: "",
      lastAccessedAt: now,
      workingDirectory: normalizedWorkingDirectory,
      provider: provider
    )

    pendingNewSessionMode = mode
    replacePendingNewSession(with: session)
  }

  public func completePendingNewSession(sessionId: String) {
    let normalizedSessionID = sessionId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedSessionID.isEmpty else { return }

    selectedSessionId = normalizedSessionID

    guard let pendingNewSession else { return }

    let completedPendingSession = StoredSession(
      id: normalizedSessionID,
      createdAt: pendingNewSession.createdAt,
      firstUserMessage: pendingNewSession.firstUserMessage,
      lastAccessedAt: Date(),
      messages: pendingNewSession.messages,
      workingDirectory: pendingNewSession.workingDirectory,
      branchName: pendingNewSession.branchName,
      isWorktree: pendingNewSession.isWorktree,
      provider: pendingNewSession.provider
    )

    replacePendingNewSession(with: completedPendingSession)
  }

  // MARK: - Actions

  public func toggleSidebar() {
    isSidebarVisible.toggle()
  }

  public func requestNewSession() {
    newSessionInitialMode = .mockInterview
    isNewSessionModeSelectionLocked = false
    isNewSessionSheetPresented = true
  }

  public func requestDashboard() {
    onDashboardToggle?()
  }

  func startSession(_ request: ChatService.NewSessionRequest) {
    isNewSessionSheetPresented = false
    preparePendingNewSession(
      mode: request.mode,
      provider: request.provider ?? .claude,
      workingDirectory: nil
    )
    onStartSession?(request)
  }

  func selectSession(_ session: StoredSession) {
    if isPendingNewSession(session) {
      selectedSessionId = session.id
      return
    }

    clearPendingNewSession()
    selectedSessionId = session.id
    onSessionSelected?(session)
  }

  func deleteSession(_ session: StoredSession) {
    if isPendingNewSession(session) {
      clearPendingNewSession()
      return
    }

    onDeleteSession?(session)
  }

  // MARK: - Private

  private func replacePendingNewSession(with session: StoredSession) {
    let previousPendingSessionID = pendingNewSession?.id
    pendingNewSession = session
    selectedSessionId = session.id

    if let previousPendingSessionID, previousPendingSessionID != session.id {
      removeRowFromLoadedSessions(id: previousPendingSessionID)
    }

    applyPendingNewSessionToLoadedSessions()
  }

  private func clearPendingNewSession() {
    guard let pendingNewSession else { return }

    self.pendingNewSession = nil
    removeRowFromLoadedSessions(id: pendingNewSession.id)

    if selectedSessionId == pendingNewSession.id {
      selectedSessionId = nil
    }
  }

  private func sessionsIncludingPendingNewSession(_ sessions: [StoredSession]) -> [StoredSession] {
    guard let pendingNewSession else { return sessions }

    if sessions.contains(where: { $0.id == pendingNewSession.id }) {
      self.pendingNewSession = nil
      return sessions
    }

    if let replacementSession = sessions.first(where: { storedSession in
      Self.normalizedWorkingDirectory(storedSession.workingDirectory) == pendingNewSession.workingDirectory
        && storedSession.lastAccessedAt >= pendingNewSession.createdAt
    }), pendingNewSession.workingDirectory != nil {
      self.pendingNewSession = nil
      if selectedSessionId == pendingNewSession.id {
        selectedSessionId = replacementSession.id
      }
      return sessions
    }

    return [pendingNewSession] + sessions
  }

  /// A synthetic attempt carries the pending row's selected mode until its
  /// persisted interview attempt becomes available.
  private func attemptsIncludingPendingPlaceholder(_ attempts: [InterviewAttempt]) -> [InterviewAttempt] {
    guard let pendingNewSession else { return attempts }
    return attempts + [pendingAttempt(for: pendingNewSession)]
  }

  private func applyPendingNewSessionToLoadedSessions() {
    guard let pendingNewSession else { return }

    let row = AttemptRow(
      session: pendingNewSession,
      attempt: pendingAttempt(for: pendingNewSession)
    )
    sessionRows.removeAll { $0.id == pendingNewSession.id }
    sessionRows.insert(row, at: 0)
  }

  private func removeRowFromLoadedSessions(id sessionID: String) {
    sessionRows.removeAll { $0.id == sessionID }
  }

  private func pendingAttempt(for session: StoredSession) -> InterviewAttempt {
    InterviewAttempt(
      chatSessionId: session.id,
      provider: session.provider.rawValue,
      mode: pendingNewSessionMode,
      startedAt: session.createdAt
    )
  }

  private func isPendingNewSession(_ session: StoredSession) -> Bool {
    pendingNewSession?.id == session.id
  }

  private static func normalizedWorkingDirectory(_ workingDirectory: String?) -> String? {
    let trimmed = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }
}
