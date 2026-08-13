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
    func createWorkspace(slug: String, kind: InterviewWorkspaceKind) throws -> String { path }
    func deleteWorkspace(atPath path: String) throws {}
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

  @Test
  func discardRemovesAnAttemptThatFailedDuringPreparation() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = try await service.beginAttempt(mode: .codingProject, provider: "codex")
    await service.discardActiveAttempt()

    #expect(service.activeAttempt == nil)
    #expect(try await storage.attempt(id: attempt.id) == nil)
  }

  @Test
  func timedWorkResetsThePersistedStartAfterProjectPreparation() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = try await service.beginAttempt(
      mode: .codingProject,
      durationSeconds: 3_600,
      provider: "codex"
    )
    try await Task.sleep(for: .milliseconds(10))
    await service.startTimedWork()

    let stored = try #require(try await storage.attempt(id: attempt.id))
    #expect(stored.startedAt > attempt.startedAt)
    let deadline = try #require(service.attemptDeadline)
    #expect(abs(deadline.timeIntervalSince(stored.startedAt) - 3_600) < 0.01)
  }

  @Test
  func beginningNewAttemptAbandonsUnfinishedAttempt() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let first = try await service.beginAttempt(mode: .practice, provider: "codex")
    let second = try await service.beginAttempt(mode: .practice, provider: "codex")

    let storedFirst = try #require(try await storage.attempt(id: first.id))
    #expect(storedFirst.status == .abandoned)
    #expect(storedFirst.endedAt != nil)
    #expect(service.activeAttempt?.id == second.id)
  }

  @Test
  func restoringAnotherSessionAbandonsUnfinishedAttempt() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let restoredAttempt = try await service.beginAttempt(mode: .practice, provider: "codex")
    await service.linkChatSession("chat-restored")
    service.clearActiveAttempt()

    let unfinishedAttempt = try await service.beginAttempt(mode: .practice, provider: "codex")
    await service.linkChatSession("chat-unfinished")

    let restored = await service.restoreAttempt(forChatSessionId: "chat-restored")

    #expect(restored?.id == restoredAttempt.id)
    #expect(service.activeAttempt?.id == restoredAttempt.id)
    let storedUnfinished = try #require(try await storage.attempt(id: unfinishedAttempt.id))
    #expect(storedUnfinished.status == .abandoned)
  }

  @Test
  func leavingAttemptPreservesAwaitingEvaluationStatus() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = try await service.beginAttempt(mode: .practice, provider: "api")
    await service.requestEvaluation()
    await service.leaveActiveAttempt()

    #expect(service.activeAttempt == nil)
    let stored = try #require(try await storage.attempt(id: attempt.id))
    #expect(stored.status == .awaitingEvaluation)
  }
}
