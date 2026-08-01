//
//  InterviewSessionServiceTests.swift
//  InterviewKitTests
//

import Foundation
import Testing
@testable import InterviewKit

@MainActor
struct InterviewSessionServiceTests {

  private struct FixedWorkspaceManager: InterviewWorkspaceManaging {
    let path: String
    func createWorkspace(slug: String) throws -> String { path }
  }

  private func makeService() -> (InterviewSessionService, InterviewSQLiteStorage, URL) {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("InterviewSessionServiceTests-\(UUID().uuidString)", isDirectory: true)
    let storage = InterviewSQLiteStorage(applicationSupportDirectory: root)
    let service = InterviewSessionService(
      storage: storage,
      workspaceManager: FixedWorkspaceManager(path: root.appendingPathComponent("ws").path)
    )
    return (service, storage, root)
  }

  @Test
  func beginLinkEvaluateLifecycle() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = try await service.beginAttempt(
      mode: .drill,
      durationSeconds: 1200,
      hintBudget: 3,
      provider: "claude"
    )
    #expect(service.activeAttempt?.id == attempt.id)
    #expect(service.hintsRemaining == 3)
    #expect(service.attemptDeadline != nil)

    await service.linkChatSession("chat-9")
    let linked = try await storage.attempt(forChatSessionId: "chat-9")
    #expect(linked?.id == attempt.id)

    await service.recordHintUsed()
    #expect(service.hintsRemaining == 2)

    await service.requestEvaluation()
    #expect(service.activeAttempt?.status == .awaitingEvaluation)

    var evaluationFired = false
    service.onEvaluationCompleted = { _ in evaluationFired = true }
    let evaluation = RubricEvaluation(
      attemptId: attempt.id,
      overallScore: 85,
      summaryMarkdown: "Nice",
      rawJSON: "{}"
    )
    await service.completeEvaluation(evaluation, notes: [])

    #expect(evaluationFired)
    #expect(service.activeAttempt?.status == .evaluated)
    let persisted = try await storage.evaluation(forAttemptId: attempt.id)
    #expect(persisted?.overallScore == 85)
  }

  @Test
  func questionCapturedMidSessionAttachesToAttempt() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    _ = try await service.beginAttempt(mode: .mockInterview, provider: "claude")
    let question = Question(
      mode: .mockInterview,
      title: "Two Sum",
      promptMarkdown: "…",
      difficulty: .easy
    )
    try await storage.saveQuestion(question)
    await service.attachQuestion(question)

    #expect(service.activeAttempt?.questionId == question.id)
    #expect(service.activeQuestion?.title == "Two Sum")
  }

  @Test
  func restoreAttemptFromChatSession() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = try await service.beginAttempt(mode: .behavioral, provider: "codex")
    await service.linkChatSession("chat-restore")
    service.clearActiveAttempt()
    #expect(service.activeAttempt == nil)

    let restored = await service.restoreAttempt(forChatSessionId: "chat-restore")
    #expect(restored?.id == attempt.id)
    #expect(service.activeAttempt?.mode == .behavioral)

    _ = storage
  }

  @Test
  func abandonClearsActiveAttempt() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = try await service.beginAttempt(mode: .practice, provider: "api")
    await service.abandon()
    #expect(service.activeAttempt == nil)

    let stored = try await storage.attempt(id: attempt.id)
    #expect(stored?.status == .abandoned)
  }
}
