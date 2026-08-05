//
//  InterviewIntegrationTests.swift
//  CodingBuddyChatTests
//
//  WP4 gate: the buddy-question / buddy-eval loop persists rows across the
//  questions, attempts, and evaluations tables, driven through ChatService's
//  assistant-turn hook exactly as a live provider would.
//

import ClaudeCodeCore
import Foundation
import InterviewKit
import Testing
@testable import CodingBuddyChat

@MainActor
struct InterviewIntegrationTests {

  private func makeService() -> (ChatService, InterviewSQLiteStorage, URL) {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("InterviewIntegrationTests-\(UUID().uuidString)", isDirectory: true)
    let interviewStorage = InterviewSQLiteStorage(applicationSupportDirectory: root)
    let service = ChatService(
      sessionStorage: NoOpSessionStorage(),
      interviewStorage: interviewStorage,
      workspaceManager: InterviewWorkspaceManager(
        rootDirectory: root.appendingPathComponent("Workspaces", isDirectory: true)
      )
    )
    return (service, interviewStorage, root)
  }

  private func assistantMessage(_ content: String) -> ChatMessage {
    ChatMessage(role: .assistant, content: content, isComplete: true)
  }

  /// Polls until `condition` is true or the timeout elapses (capture work
  /// happens on detached MainActor tasks).
  private func waitUntil(
    timeout: TimeInterval = 3,
    _ condition: @MainActor () async -> Bool
  ) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if await condition() { return true }
      try? await Task.sleep(for: .milliseconds(50))
    }
    return await condition()
  }

  @Test
  func drillSessionQuestionAndEvaluationPersistEndToEnd() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    await service.startNewSession(ChatService.NewSessionRequest(
      mode: .practice,
      durationSeconds: nil,
      hintBudget: 3
    ))
    let vm = try #require(service.chatViewModel)
    let attempt = try #require(service.interviewSession.activeAttempt)
    #expect(service.currentMode == .practice)
    #expect(attempt.workspacePath != nil)

    // 1. Agent presents a question → captured into the bank + attached.
    vm.onAssistantTurnCompleted?(nil, assistantMessage("""
      Here's your problem:

      ```buddy-question
      {"schema":"buddy-question/v1","title":"Two Sum","difficulty":"easy","topics":["hash-maps"],"prompt_markdown":"Given nums and target…","reference_notes":"One-pass hash map."}
      ```

      Given an array of integers…
      """))

    let questionCaptured = await waitUntil {
      let questions = (try? await storage.questions(mode: nil, topicId: nil, difficulty: nil)) ?? []
      return questions.contains { $0.title == "Two Sum" }
    }
    #expect(questionCaptured)
    #expect(service.interviewSession.activeQuestion?.title == "Two Sum")
    let savedQuestion = try #require(service.interviewSession.activeQuestion)
    #expect(savedQuestion.referenceNotes == "One-pass hash map.")

    // 2. End & grade → agent replies with a buddy-eval fence.
    await service.interviewSession.requestEvaluation()
    vm.onAssistantTurnCompleted?(nil, assistantMessage("""
      Great session. Here's my assessment:

      ```buddy-eval
      {"schema":"buddy-eval/v1","overall_score":78,
       "dimensions":[{"id":"correctness","score":8,"max":10,"comment":"Clean"},
                     {"id":"complexity_analysis","score":7,"max":10}],
       "summary_markdown":"Solid hash-map solution.",
       "improvement_notes":[{"topic":"dynamic-programming","note":"Practice DP next."}]}
      ```
      """))

    let evaluated = await waitUntil {
      (try? await storage.evaluation(forAttemptId: attempt.id))?.overallScore == 78
    }
    #expect(evaluated)

    // 3. All three tables hold the linked rows.
    let storedAttempt = try #require(try await storage.attempt(id: attempt.id))
    #expect(storedAttempt.status == .evaluated)
    #expect(storedAttempt.questionId == savedQuestion.id)

    let evaluation = try #require(try await storage.evaluation(forAttemptId: attempt.id))
    #expect(evaluation.dimensionScores.count == 2)

    let notes = try await storage.openImprovementNotes()
    #expect(notes.contains { $0.topicId == "dynamic-programming" })

    let stats = try await storage.topicSkillStats()
    #expect(stats.contains { $0.topicId == "hash-maps" && $0.attemptCount == 1 })
  }

  @Test
  func deletingSessionRemovesLinkedAttemptAndWorkspace() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = try await service.interviewSession.beginAttempt(
      mode: .practice,
      provider: "codex"
    )
    await service.interviewSession.linkChatSession("session-to-delete")
    let workspacePath = try #require(attempt.workspacePath)
    let workspaceURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
    #expect(FileManager.default.fileExists(atPath: workspaceURL.path))

    await service.deleteSession(StoredSession(
      id: "session-to-delete",
      createdAt: .now,
      firstUserMessage: "Practice",
      lastAccessedAt: .now,
      workingDirectory: workspacePath,
      provider: .codex
    ))

    #expect(!FileManager.default.fileExists(atPath: workspaceURL.path))
    #expect(try await storage.attempt(id: attempt.id) == nil)
  }

  @Test
  func duplicateTurnReportsAreCapturedOnce() async throws {
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    await service.startNewSession(ChatService.NewSessionRequest(mode: .practice))
    let vm = try #require(service.chatViewModel)

    let message = assistantMessage("""
      ```buddy-question
      {"schema":"buddy-question/v1","title":"Unique Capture","difficulty":"easy","prompt_markdown":"…"}
      ```
      """)
    vm.onAssistantTurnCompleted?(nil, message)
    vm.onAssistantTurnCompleted?(nil, message)

    _ = await waitUntil {
      let questions = (try? await storage.questions(mode: nil, topicId: nil, difficulty: nil)) ?? []
      return !questions.isEmpty
    }
    let questions = try await storage.questions(mode: nil, topicId: nil, difficulty: nil)
    #expect(questions.filter { $0.title == "Unique Capture" }.count == 1)
  }

  @Test
  func timerRestoresFromPersistedAttemptDeadline() async throws {
    let (service, _, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    await service.startNewSession(ChatService.NewSessionRequest(
      mode: .practice,
      durationSeconds: 1800,
      hintBudget: 3
    ))
    #expect(service.sessionTimer.isRunning)
    let remaining = try #require(service.sessionTimer.remaining)
    #expect(remaining > 1790 && remaining <= 1800)
  }

  @Test
  func hintRequestIncrementsCounter() async throws {
    // No chat context on purpose: requestHint's send becomes a no-op so the
    // test never spawns a provider CLI; the deterministic counter still runs.
    let (service, storage, root) = makeService()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = try await service.interviewSession.beginAttempt(
      mode: .mockInterview,
      hintBudget: 2,
      provider: "claude"
    )

    service.requestHint()
    let counted = await waitUntil {
      (try? await storage.attempt(id: attempt.id))?.hintsUsed == 1
    }
    #expect(counted)
    #expect(service.interviewSession.hintsRemaining == 1)
  }
}
