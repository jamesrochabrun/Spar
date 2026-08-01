//
//  SidebarViewModel.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation

@Observable @MainActor
public final class SidebarViewModel {

  // MARK: - Public State

  private(set) var sessions: [StoredSession] = []
  public var selectedSessionId: String?
  public var isSidebarVisible: Bool = true

  // MARK: - Callbacks

  public var onSessionSelected: ((StoredSession) -> Void)?
  public var onNewChatRequested: ((String?) -> Void)?
  public var onDeleteSession: ((StoredSession) -> Void)?

  // MARK: - Private

  private let sessionStorage: SessionStorageProtocol
  private var pendingNewSession: StoredSession?

  // MARK: - Init

  public init(sessionStorage: SessionStorageProtocol) {
    self.sessionStorage = sessionStorage
  }

  // MARK: - Public Methods

  public func loadSessions() async {
    do {
      let storedSessions = try await sessionStorage.getAllSessions()
      sessions = sessionsIncludingPendingNewSession(storedSessions)
    } catch {
      sessions = []
    }
  }

  public func preparePendingNewSession(workingDirectory: String?) {
    let normalizedWorkingDirectory = Self.normalizedWorkingDirectory(workingDirectory)
    let now = Date()
    let session = StoredSession(
      id: UUID().uuidString.lowercased(),
      createdAt: now,
      firstUserMessage: "",
      lastAccessedAt: now,
      workingDirectory: normalizedWorkingDirectory
    )

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

  public func toggleSidebar() {
    isSidebarVisible.toggle()
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

  func requestNewChat(workingDirectory: String?) {
    preparePendingNewSession(workingDirectory: workingDirectory)
    onNewChatRequested?(workingDirectory)
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
      sessions.removeAll { $0.id == previousPendingSessionID }
    }

    sessions.removeAll { $0.id == session.id }
    sessions.insert(session, at: 0)
  }

  private func clearPendingNewSession() {
    guard let pendingNewSession else { return }

    self.pendingNewSession = nil
    sessions.removeAll { $0.id == pendingNewSession.id }

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
    }) {
      self.pendingNewSession = nil
      if selectedSessionId == pendingNewSession.id {
        selectedSessionId = replacementSession.id
      }
      return sessions
    }

    return [pendingNewSession] + sessions
  }

  private func isPendingNewSession(_ session: StoredSession) -> Bool {
    pendingNewSession?.id == session.id
  }

  private static func normalizedWorkingDirectory(_ workingDirectory: String?) -> String? {
    let trimmed = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }
}
