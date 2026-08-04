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

  private func storedSession(id: String, firstMessage: String = "Hello") -> StoredSession {
    StoredSession(
      id: id,
      createdAt: Date(),
      firstUserMessage: firstMessage,
      lastAccessedAt: Date(),
      workingDirectory: "/tmp/\(id)"
    )
  }

  @Test
  func groupsJoinAttemptsWithSessionsByMode() async throws {
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
      storedSession(id: "chat-mock"),
      storedSession(id: "chat-drill"),
      storedSession(id: "chat-legacy", firstMessage: "Just chatting"),
    ]

    let sessionStorage = NoOpSessionStorage()
    for session in sessions {
      _ = session
    }
    _ = sessionStorage

    let attempts = try await storage.attempts(limit: nil)
    let groups = ModeGroup.groups(
      attempts: attempts,
      sessions: sessions,
      questionTitlesById: [question.id: question.title],
      scoresByAttemptId: [mockAttempt.id: 82]
    )

    let mockGroup = try #require(groups.first { $0.mode == .mockInterview })
    #expect(mockGroup.rows.count == 1)
    #expect(mockGroup.rows[0].displayTitle == "Two Sum")
    #expect(mockGroup.rows[0].overallScore == 82)

    let drillGroup = try #require(groups.first { $0.mode == .drill })
    #expect(drillGroup.rows.count == 1)
    #expect(drillGroup.rows[0].attempt?.status == .inProgress)

    // Sessions without an attempt land under Practice.
    let practiceGroup = try #require(groups.first { $0.mode == .practice })
    #expect(practiceGroup.rows.count == 1)
    #expect(practiceGroup.rows[0].displayTitle == "Just chatting")
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
  func pendingSessionRowAppearsInItsModeGroup() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      interviewStorage: storage
    )
    await viewModel.loadSessions()

    viewModel.preparePendingNewSession(mode: .drill, workingDirectory: nil)
    let drillGroup = try #require(viewModel.modeGroups.first { $0.mode == .drill })
    #expect(drillGroup.rows.count == 1)
    #expect(viewModel.selectedSessionId == drillGroup.rows[0].id)

    // Completing swaps the optimistic id for the real session id.
    viewModel.completePendingNewSession(sessionId: "real-session-id")
    #expect(viewModel.selectedSessionId == "real-session-id")
    let updatedDrillGroup = try #require(viewModel.modeGroups.first { $0.mode == .drill })
    #expect(updatedDrillGroup.rows.contains { $0.id == "real-session-id" })
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

  @Test
  func requestNewSessionCarriesModeIntoSheet() {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      interviewStorage: storage
    )

    viewModel.requestNewSession(mode: .drill)
    #expect(viewModel.isNewSessionSheetPresented)
    #expect(viewModel.newSessionInitialMode == .drill)
    #expect(viewModel.isNewSessionModeSelectionLocked)

    // A later global "+" must not inherit the previous section's mode.
    viewModel.isNewSessionSheetPresented = false
    viewModel.requestNewSession()
    #expect(viewModel.newSessionInitialMode == .mockInterview)
    #expect(!viewModel.isNewSessionModeSelectionLocked)
  }

  @Test
  func expansionStatePreservedAcrossReloads() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let viewModel = SidebarViewModel(
      sessionStorage: NoOpSessionStorage(),
      interviewStorage: storage
    )
    await viewModel.loadSessions()
    viewModel.toggleGroup(.behavioral)
    #expect(viewModel.modeGroups.first { $0.mode == .behavioral }?.isExpanded == false)

    await viewModel.loadSessions()
    #expect(viewModel.modeGroups.first { $0.mode == .behavioral }?.isExpanded == false)
  }
}
