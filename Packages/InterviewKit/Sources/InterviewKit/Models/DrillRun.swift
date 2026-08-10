//
//  DrillRun.swift
//  InterviewKit
//
//  Per-rep state for a drill session. A drill is many short problems in one
//  attempt, so the attempt row alone cannot say how the run is going: this
//  type accumulates the verdicts the agent reports (buddy-rep fences) and
//  derives the two things both the UI and the agent need — how the candidate
//  is trending, and what difficulty the next rep should be.
//

import Foundation

public enum DrillVerdict: String, Codable, CaseIterable, Sendable, Identifiable {
  case correct
  case partial
  case incorrect

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .correct: return "Correct"
    case .partial: return "Partial"
    case .incorrect: return "Missed"
    }
  }

  public var systemImage: String {
    switch self {
    case .correct: return "checkmark"
    case .partial: return "minus"
    case .incorrect: return "xmark"
    }
  }

  /// Only a clean solve extends a streak; a partial breaks it without
  /// counting against the candidate the way a miss does.
  public var isClean: Bool { self == .correct }
}

public struct DrillRep: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public var index: Int              // 1-based position in the run
  public var questionTitle: String?
  public var topicIds: [String]
  public var difficulty: Difficulty
  public var verdict: DrillVerdict
  public var note: String?           // the agent's one-line why
  public var recordedAt: Date

  public init(
    id: String = UUID().uuidString.lowercased(),
    index: Int,
    questionTitle: String? = nil,
    topicIds: [String] = [],
    difficulty: Difficulty = .medium,
    verdict: DrillVerdict,
    note: String? = nil,
    recordedAt: Date = Date()
  ) {
    self.id = id
    self.index = index
    self.questionTitle = questionTitle
    self.topicIds = topicIds
    self.difficulty = difficulty
    self.verdict = verdict
    self.note = note
    self.recordedAt = recordedAt
  }
}

public struct DrillRun: Codable, Equatable, Sendable {
  public private(set) var reps: [DrillRep]

  public init(reps: [DrillRep] = []) {
    self.reps = reps
  }

  public var isEmpty: Bool { reps.isEmpty }
  public var repCount: Int { reps.count }
  public var cleanCount: Int { reps.filter(\.verdict.isClean).count }

  /// Consecutive clean solves ending at the most recent rep.
  public var currentStreak: Int {
    var streak = 0
    for rep in reps.reversed() {
      guard rep.verdict.isClean else { break }
      streak += 1
    }
    return streak
  }

  /// Consecutive non-clean reps ending at the most recent rep — the signal to
  /// ease off before the candidate stalls out.
  public var currentStruggleStreak: Int {
    var streak = 0
    for rep in reps.reversed() {
      guard !rep.verdict.isClean else { break }
      streak += 1
    }
    return streak
  }

  public var difficultyOfLastRep: Difficulty? { reps.last?.difficulty }

  /// App-owned difficulty ladder. The agent used to be asked to adapt from
  /// "recent scores" that were never actually sent to it; this is that data,
  /// computed where the verdicts live.
  public func suggestedNextDifficulty(startingFrom requested: Difficulty) -> Difficulty {
    guard let last = difficultyOfLastRep else { return requested }
    if currentStreak >= 2 { return last.harder }
    if currentStruggleStreak >= 2 { return last.easier }
    return last
  }

  /// Topic slugs the candidate has missed or half-solved, most recent first —
  /// what the run should circle back to.
  public var shakyTopicIds: [String] {
    var seen = Set<String>()
    var result: [String] = []
    for rep in reps.reversed() where !rep.verdict.isClean {
      for topic in rep.topicIds where !seen.contains(topic) {
        seen.insert(topic)
        result.append(topic)
      }
    }
    return result
  }

  public mutating func append(_ rep: DrillRep) {
    reps.append(rep)
  }

  /// Next rep index, so callers never have to track the counter themselves.
  public var nextIndex: Int { reps.count + 1 }
}

extension Difficulty {
  public var harder: Difficulty {
    switch self {
    case .easy: return .medium
    case .medium, .hard: return .hard
    }
  }

  public var easier: Difficulty {
    switch self {
    case .hard: return .medium
    case .medium, .easy: return .easy
    }
  }
}
