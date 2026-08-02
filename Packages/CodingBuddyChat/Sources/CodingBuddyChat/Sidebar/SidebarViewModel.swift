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

  public private(set) var modeGroups: [ModeGroup] = []
  public var selectedSessionId: String?
  public var isSidebarVisible: Bool = true
  public var isNewSessionSheetPresented = false
  /// Mode the new-session sheet opens preselected to, set by the entry point
  /// (global "+", a section's "+", or an empty-state button).
  public private(set) var newSessionInitialMode: SessionMode = .mockInterview

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

      let previousExpansion = Dictionary(uniqueKeysWithValues: modeGroups.map { ($0.id, $0.isExpanded) })
      let sessionsForDisplay = sessionsIncludingPendingNewSession(sessions)
      modeGroups = ModeGroup.groups(
        attempts: attemptsIncludingPendingPlaceholder(attempts),
        sessions: sessionsForDisplay,
        questionTitlesById: questionTitlesById,
        scoresByAttemptId: scoresByAttemptId,
        previousExpansion: previousExpansion
      )
    } catch {
      modeGroups = []
    }
  }

  // MARK: - Pending session (optimistic row)

  public func preparePendingNewSession(mode: SessionMode, workingDirectory: String?) {
    let normalizedWorkingDirectory = Self.normalizedWorkingDirectory(workingDirectory)
    let now = Date()
    let session = StoredSession(
      id: UUID().uuidString.lowercased(),
      createdAt: now,
      firstUserMessage: "",
      lastAccessedAt: now,
      workingDirectory: normalizedWorkingDirectory
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
      isWorktree: pendingNewSession.isWorktree
    )

    replacePendingNewSession(with: completedPendingSession)
  }

  // MARK: - Actions

  public func toggleSidebar() {
    isSidebarVisible.toggle()
  }

  public func requestNewSession(mode: SessionMode = .mockInterview) {
    newSessionInitialMode = mode
    isNewSessionSheetPresented = true
  }

  public func requestDashboard() {
    onDashboardToggle?()
  }

  func startSession(_ request: ChatService.NewSessionRequest) {
    isNewSessionSheetPresented = false
    preparePendingNewSession(mode: request.mode, workingDirectory: nil)
    onStartSession?(request)
  }

  func toggleGroup(_ mode: SessionMode) {
    guard let index = modeGroups.firstIndex(where: { $0.mode == mode }) else { return }
    modeGroups[index].isExpanded.toggle()
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
      removeRowFromLoadedGroups(id: previousPendingSessionID)
    }

    applyPendingNewSessionToLoadedGroups()
  }

  private func clearPendingNewSession() {
    guard let pendingNewSession else { return }

    self.pendingNewSession = nil
    removeRowFromLoadedGroups(id: pendingNewSession.id)

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

  /// Synthetic attempt so the pending session row lands in its mode's group
  /// rather than defaulting to Practice.
  private func attemptsIncludingPendingPlaceholder(_ attempts: [InterviewAttempt]) -> [InterviewAttempt] {
    guard let pendingNewSession, pendingNewSessionMode != .practice else { return attempts }

    let placeholder = InterviewAttempt(
      chatSessionId: pendingNewSession.id,
      provider: "claude",
      mode: pendingNewSessionMode,
      startedAt: pendingNewSession.createdAt
    )
    return attempts + [placeholder]
  }

  private func applyPendingNewSessionToLoadedGroups() {
    guard let pendingNewSession else { return }

    let row = AttemptRow(session: pendingNewSession)
    for index in modeGroups.indices {
      modeGroups[index].rows.removeAll { $0.id == pendingNewSession.id }
      if modeGroups[index].mode == pendingNewSessionMode {
        modeGroups[index].rows.insert(row, at: 0)
        modeGroups[index].isExpanded = true
      }
    }
  }

  private func removeRowFromLoadedGroups(id sessionID: String) {
    for index in modeGroups.indices {
      modeGroups[index].rows.removeAll { $0.id == sessionID }
    }
  }

  private func isPendingNewSession(_ session: StoredSession) -> Bool {
    pendingNewSession?.id == session.id
  }

  private static func normalizedWorkingDirectory(_ workingDirectory: String?) -> String? {
    let trimmed = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }
}
