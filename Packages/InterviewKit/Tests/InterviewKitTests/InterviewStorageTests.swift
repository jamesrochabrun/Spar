//
//  InterviewStorageTests.swift
//  InterviewKitTests
//

import Foundation
import SQLite
import Testing
@testable import InterviewKit

struct InterviewStorageTests {

  private func makeStorage() -> (InterviewSQLiteStorage, URL) {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("InterviewKitTests-\(UUID().uuidString)", isDirectory: true)
    return (InterviewSQLiteStorage(applicationSupportDirectory: root), root)
  }

  @Test
  func freshDatabaseSeedsTopics() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let topics = try await storage.allTopics()
    #expect(topics.count >= 26)
    #expect(topics.contains { $0.id == "two-pointers" && $0.category == "algorithms" })
    #expect(topics.contains { $0.id == "sd-caching" && $0.category == "system-design" })
    #expect(topics.contains { $0.id == "bh-ownership" && $0.category == "behavioral" })
    #expect(topics.contains { $0.id == "ios-concurrency" && $0.category == "ios" })
    #expect(topics.contains { $0.id == "sd-offline-sync" && $0.category == "system-design" })
  }

  @Test
  func seedVersionBumpReseedsExistingDatabase() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    _ = try await storage.allTopics() // initialize + seed at the current version

    // Rewind to a v1-era database: no iOS topics, old seed flag.
    let dbPath = root.appendingPathComponent("CodingBuddy/interview_bank.sqlite").path
    let database = try Connection(dbPath)
    try database.run("DELETE FROM topics WHERE category = 'ios'")
    try database.run("INSERT OR REPLACE INTO app_meta (key, value) VALUES ('topics_seeded', '1')")

    let upgraded = InterviewSQLiteStorage(applicationSupportDirectory: root)
    let topics = try await upgraded.allTopics()
    #expect(topics.contains { $0.id == "ios-swift-language" && $0.category == "ios" })
  }

  @Test
  func questionRoundTripWithTopics() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let question = Question(
      mode: .drill,
      title: "Longest Substring Without Repeating Characters",
      promptMarkdown: "Given a string `s`, find the length…",
      difficulty: .medium,
      topicIds: ["sliding-window", "strings"],
      languageHint: "swift",
      referenceNotes: "Sliding window with a set."
    )
    try await storage.saveQuestion(question)

    let fetched = try await storage.question(id: question.id)
    #expect(fetched?.title == question.title)
    #expect(fetched?.topicIds.sorted() == ["sliding-window", "strings"])
    #expect(fetched?.referenceNotes == "Sliding window with a set.")

    let byTopic = try await storage.questions(mode: .drill, topicId: "sliding-window", difficulty: .medium)
    #expect(byTopic.count == 1)

    let miss = try await storage.questions(mode: .drill, topicId: "graphs", difficulty: nil)
    #expect(miss.isEmpty)
  }

  @Test
  func attemptLifecycleRoundTrip() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    var attempt = InterviewAttempt(
      provider: "claude",
      mode: .mockInterview,
      plannedDurationSeconds: 2100,
      hintBudget: 3
    )
    try await storage.createAttempt(attempt)

    try await storage.linkChatSession(attemptId: attempt.id, chatSessionId: "chat-123")
    let byChatSession = try await storage.attempt(forChatSessionId: "chat-123")
    #expect(byChatSession?.id == attempt.id)

    attempt.status = .evaluated
    attempt.hintsUsed = 2
    attempt.endedAt = Date()
    try await storage.updateAttempt(attempt)

    let fetched = try await storage.attempt(id: attempt.id)
    #expect(fetched?.status == .evaluated)
    #expect(fetched?.hintsUsed == 2)
    #expect(fetched?.plannedDurationSeconds == 2100)

    let all = try await storage.attempts(limit: 10)
    #expect(all.count == 1)
  }

  @Test
  func evaluationRoundTripWithScoresAndNotes() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = InterviewAttempt(provider: "claude", mode: .drill)
    try await storage.createAttempt(attempt)

    let evaluation = RubricEvaluation(
      attemptId: attempt.id,
      overallScore: 72,
      summaryMarkdown: "Solid but slow.",
      dimensionScores: [
        DimensionScore(dimension: "correctness", score: 7, comment: "Handled all cases"),
        DimensionScore(dimension: "speed", score: 5),
      ],
      rawJSON: "{}"
    )
    let notes = [
      ImprovementNote(attemptId: attempt.id, topicId: "dynamic-programming", noteMarkdown: "Practice DP."),
      ImprovementNote(attemptId: attempt.id, noteMarkdown: "Talk through complexity earlier."),
    ]
    try await storage.saveEvaluation(evaluation, notes: notes)

    let fetched = try await storage.evaluation(forAttemptId: attempt.id)
    #expect(fetched?.overallScore == 72)
    #expect(fetched?.dimensionScores.count == 2)

    let openNotes = try await storage.openImprovementNotes()
    #expect(openNotes.count == 2)

    try await storage.setNoteResolved(id: notes[0].id, resolved: true)
    let remaining = try await storage.openImprovementNotes()
    #expect(remaining.count == 1)
  }

  @Test
  func deletingAttemptCascadesEvaluationAndNotes() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let attempt = InterviewAttempt(provider: "codex", mode: .practice)
    try await storage.createAttempt(attempt)
    try await storage.saveEvaluation(
      RubricEvaluation(
        attemptId: attempt.id,
        overallScore: 88,
        summaryMarkdown: "Strong technical work.",
        rawJSON: "{}"
      ),
      notes: [
        ImprovementNote(
          attemptId: attempt.id,
          topicId: "graphs",
          noteMarkdown: "Practice graph traversal."
        ),
      ]
    )

    try await storage.deleteAttempt(id: attempt.id)

    #expect(try await storage.attempt(id: attempt.id) == nil)
    #expect(try await storage.evaluation(forAttemptId: attempt.id) == nil)
    #expect(try await storage.notes(forAttemptId: attempt.id).isEmpty)
  }

  @Test
  func topicSkillStatsAggregatesEvaluatedAttempts() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let question = Question(
      mode: .drill,
      title: "Two Sum",
      promptMarkdown: "…",
      difficulty: .easy,
      topicIds: ["hash-maps"]
    )
    try await storage.saveQuestion(question)

    for score in [60.0, 80.0] {
      var attempt = InterviewAttempt(questionId: question.id, provider: "claude", mode: .drill)
      attempt.status = .evaluated
      try await storage.createAttempt(attempt)
      try await storage.saveEvaluation(
        RubricEvaluation(attemptId: attempt.id, overallScore: score, summaryMarkdown: "", rawJSON: "{}"),
        notes: []
      )
    }

    let stats = try await storage.topicSkillStats()
    let hashMaps = stats.first { $0.topicId == "hash-maps" }
    #expect(hashMaps?.attemptCount == 2)
    #expect(hashMaps?.averageScore == 70)
    #expect(hashMaps?.trend.count == 2)
  }

  @Test
  func saveQuestionRegistersUnknownTopicSlugs() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let question = Question(
      mode: .practice,
      title: "Custom",
      promptMarkdown: "…",
      difficulty: .easy,
      topicIds: ["brand-new-topic"]
    )
    try await storage.saveQuestion(question)

    let topics = try await storage.allTopics()
    #expect(topics.contains { $0.id == "brand-new-topic" })
  }
}
