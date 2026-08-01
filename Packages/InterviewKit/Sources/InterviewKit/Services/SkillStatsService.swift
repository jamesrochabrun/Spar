//
//  SkillStatsService.swift
//  InterviewKit
//

import Foundation
import Observation

/// Read models for the dashboard: topic skill stats, open improvement notes,
/// recent attempts with joined question titles and scores.
@Observable @MainActor
public final class SkillStatsService {

  public struct AttemptSummary: Identifiable, Sendable {
    public let attempt: InterviewAttempt
    public let questionTitle: String?
    public let overallScore: Double?

    public var id: String { attempt.id }
  }

  public private(set) var topics: [Topic] = []
  public private(set) var topicStats: [TopicSkillStat] = []
  public private(set) var openNotes: [ImprovementNote] = []
  public private(set) var recentAttempts: [AttemptSummary] = []

  private let storage: any InterviewStorageProtocol

  public init(storage: any InterviewStorageProtocol) {
    self.storage = storage
  }

  public func refresh() async {
    topics = (try? await storage.allTopics()) ?? []
    topicStats = (try? await storage.topicSkillStats()) ?? []
    openNotes = (try? await storage.openImprovementNotes()) ?? []

    var summaries: [AttemptSummary] = []
    let attempts = (try? await storage.attempts(limit: 50)) ?? []
    for attempt in attempts {
      var questionTitle: String?
      if let questionId = attempt.questionId {
        questionTitle = (try? await storage.question(id: questionId))?.title
      }
      let score = (try? await storage.evaluation(forAttemptId: attempt.id))?.overallScore
      summaries.append(AttemptSummary(
        attempt: attempt,
        questionTitle: questionTitle,
        overallScore: score
      ))
    }
    recentAttempts = summaries
  }

  public func setNoteResolved(_ note: ImprovementNote, resolved: Bool) async {
    try? await storage.setNoteResolved(id: note.id, resolved: resolved)
    await refresh()
  }

  public func topic(for id: String) -> Topic? {
    topics.first { $0.id == id }
  }

  public func stats(forCategory category: String) -> [TopicSkillStat] {
    let categoryTopicIds = Set(topics.filter { $0.category == category }.map(\.id))
    return topicStats.filter { categoryTopicIds.contains($0.topicId) }
  }
}
