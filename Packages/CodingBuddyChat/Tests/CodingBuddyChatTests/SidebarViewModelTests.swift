//
//  SidebarViewModelTests.swift
//  CodingBuddyChatTests
//

import ClaudeCodeCore
import Foundation
import InterviewKit
import Testing
@testable import CodingBuddyChat

@MainActor
struct SidebarViewModelTests {

  private func makeStorage() -> (InterviewSQLiteStorage, URL) {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SidebarViewModelTests-\(UUID().uuidString)", isDirectory: true)
    return (InterviewSQLiteStorage(applicationSupportDirectory: root), root)
  }

  private func storedSession(
    id: String,
    firstMessage: String = "Hello",
    lastAccessedAt: Date = Date()
  ) -> StoredSession {
    StoredSession(
      id: id,
      createdAt: lastAccessedAt.addingTimeInterval(-60),
      firstUserMessage: firstMessage,
      lastAccessedAt: lastAccessedAt,
      workingDirectory: "/tmp/\(id)"
    )
  }

  @Test
  func rowsJoinAttemptMetadataAndSortByRecentActivity() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let question = Question(mode: .mockInterview, title: "Two Sum", promptMarkdown: "…", difficulty: .easy)
    try await storage.saveQuestion(question)

    var mockAttempt = InterviewAttempt(questionId: question.id, provider: "claude", mode: .mockInterview)
    mockAttempt.chatSessionId = "chat-mock"
    mockAttempt.status = .evaluated
    try await storage.createAttempt(mockAttempt)
    try await storage.saveEvaluation(
      RubricEvaluation(attemptId: mockAttempt.id, overallScore: 82, summaryMarkdown: "", rawJSON: "{}"),
      notes: []
    )

    var drillAttempt = InterviewAttempt(provider: "codex", mode: .drill)
    drillAttempt.chatSessionId = "chat-drill"
    try await storage.createAttempt(drillAttempt)

    let sessions = [
      storedSession(id: "chat-mock", lastAccessedAt: Date(timeIntervalSince1970: 100)),
      storedSession(id: "chat-drill", lastAccessedAt: Date(timeIntervalSince1970: 300)),
      storedSession(
        id: "chat-legacy",
        firstMessage: "Just chatting",
        lastAccessedAt: Date(timeIntervalSince1970: 200)
      ),
    ]

    let attempts = try await storage.attempts(limit: nil)
    let rows = AttemptRow.rows(
      attempts: attempts,
      sessions: sessions,
      questionTitlesById: [question.id: question.title],
      scoresByAttemptId: [mockAttempt.id: 82]
    )

    #expect(rows.map(\.id) == ["chat-drill", "chat-legacy", "chat-mock"])
    #expect(rows.map(\.mode) == [.drill, .practice, .mockInterview])
    #expect(rows[0].attempt?.status == .inProgress)
    #expect(rows[1].displayTitle == "Just chatting")
    #expect(rows[2].displayTitle == "Two Sum")
    #expect(rows[2].overallScore == 82)
  }

  @Test
  func groupsKeepFixedDisplayOrder() {
    let groups = ModeGroup.groups(
      attempts: [],
      sessions: [],
      questionTitlesById: [:],
      scoresByAttemptId: [:]
    )
    #expect(groups.map(\.mode) == ModeGroup.displayOrder)
  }

  @Test
  func pendingSessionRowAppearsFirstWithItsMode() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      interviewStorage: storage
    )
    await viewModel.loadSessions()

    viewModel.preparePendingNewSession(mode: .drill, provider: .claude, workingDirectory: nil)
    let pendingRow = try #require(viewModel.sessionRows.first)
    #expect(viewModel.sessionRows.count == 1)
    #expect(pendingRow.mode == .drill)
    #expect(viewModel.selectedSessionId == pendingRow.id)
    // The optimistic row must show the provider the user picked, not a default.
    #expect(pendingRow.session.provider == .claude)

    // Completing swaps the optimistic id for the real session id.
    viewModel.completePendingNewSession(sessionId: "real-session-id")
    #expect(viewModel.selectedSessionId == "real-session-id")
    #expect(viewModel.sessionRows.first?.id == "real-session-id")
    #expect(viewModel.sessionRows.first?.mode == .drill)
  }

  @Test
  func requestNewSessionDefaultsToMockInterview() {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      interviewStorage: storage
    )

    viewModel.requestNewSession()
    #expect(viewModel.isNewSessionSheetPresented)
    #expect(viewModel.newSessionInitialMode == .mockInterview)
    #expect(!viewModel.isNewSessionModeSelectionLocked)
  }

}
