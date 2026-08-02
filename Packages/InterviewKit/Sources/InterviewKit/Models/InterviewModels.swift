//
//  InterviewModels.swift
//  InterviewKit
//

import Foundation

public enum SessionMode: String, Codable, CaseIterable, Sendable, Identifiable {
  case mockInterview = "mock_interview"   // timed, AI interviewer, rubric-graded
  case practice                           // untimed tutor / study projects
  case systemDesign = "system_design"     // diagram-centric (excalidraw MCP app)
  case behavioral                         // STAR coaching
  case drill                              // rapid-fire LeetCode-style, progressive difficulty

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .mockInterview: return "Mock Interview"
    case .practice: return "Practice"
    case .systemDesign: return "System Design"
    case .behavioral: return "Behavioral"
    case .drill: return "Drills"
    }
  }

  public var systemImage: String {
    switch self {
    case .mockInterview: return "person.crop.rectangle.badge.clock"
    case .practice: return "book"
    case .systemDesign: return "rectangle.3.group"
    case .behavioral: return "bubble.left.and.bubble.right"
    case .drill: return "bolt"
    }
  }

  /// One-line description of how the mode is used, shown under its name.
  public var usageSubtitle: String {
    switch self {
    case .mockInterview: return "One timed problem, graded like the real thing"
    case .drill: return "Rapid-fire reps, difficulty adapts to you"
    case .practice: return "Untimed tutoring — learn, ask, see solutions"
    case .systemDesign: return "Design on the whiteboard, defend trade-offs"
    case .behavioral: return "STAR stories with probing follow-ups"
    }
  }

  /// Modes with a countdown timer by default.
  public var isTimedByDefault: Bool {
    switch self {
    case .mockInterview, .drill: return true
    case .practice, .systemDesign, .behavioral: return false
    }
  }
}

public enum Difficulty: String, Codable, CaseIterable, Sendable, Identifiable {
  case easy, medium, hard

  public var id: String { rawValue }

  public var displayName: String { rawValue.capitalized }
}

public struct Question: Identifiable, Codable, Equatable, Sendable {
  public let id: String            // UUID string
  public var createdAt: Date
  public var mode: SessionMode
  public var title: String
  public var promptMarkdown: String
  public var difficulty: Difficulty
  public var topicIds: [String]    // slugs, e.g. "two-pointers"
  public var languageHint: String?
  public var referenceNotes: String?   // generator's solution sketch — never shown during attempts
  public var archived: Bool

  public init(
    id: String = UUID().uuidString.lowercased(),
    createdAt: Date = Date(),
    mode: SessionMode,
    title: String,
    promptMarkdown: String,
    difficulty: Difficulty,
    topicIds: [String] = [],
    languageHint: String? = nil,
    referenceNotes: String? = nil,
    archived: Bool = false
  ) {
    self.id = id
    self.createdAt = createdAt
    self.mode = mode
    self.title = title
    self.promptMarkdown = promptMarkdown
    self.difficulty = difficulty
    self.topicIds = topicIds
    self.languageHint = languageHint
    self.referenceNotes = referenceNotes
    self.archived = archived
  }
}

public struct InterviewAttempt: Identifiable, Codable, Equatable, Sendable {
  public enum Status: String, Codable, Sendable {
    case inProgress = "in_progress"
    case awaitingEvaluation = "awaiting_evaluation"
    case evaluated
    case abandoned
  }

  public let id: String
  public var questionId: String?
  public var chatSessionId: String?    // soft link into claude_code_sessions.sqlite
  public var provider: String          // ChatProvider.rawValue: "claude" | "codex" | "api"
  public var mode: SessionMode
  public var status: Status
  public var startedAt: Date
  public var endedAt: Date?
  public var plannedDurationSeconds: Int?   // nil = untimed
  public var hintBudget: Int
  public var hintsUsed: Int
  public var workspacePath: String?    // ~/Documents/CodingBuddy/Workspaces/<slug>

  public init(
    id: String = UUID().uuidString.lowercased(),
    questionId: String? = nil,
    chatSessionId: String? = nil,
    provider: String,
    mode: SessionMode,
    status: Status = .inProgress,
    startedAt: Date = Date(),
    endedAt: Date? = nil,
    plannedDurationSeconds: Int? = nil,
    hintBudget: Int = 0,
    hintsUsed: Int = 0,
    workspacePath: String? = nil
  ) {
    self.id = id
    self.questionId = questionId
    self.chatSessionId = chatSessionId
    self.provider = provider
    self.mode = mode
    self.status = status
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.plannedDurationSeconds = plannedDurationSeconds
    self.hintBudget = hintBudget
    self.hintsUsed = hintsUsed
    self.workspacePath = workspacePath
  }
}

public struct RubricEvaluation: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public var attemptId: String
  public var createdAt: Date
  public var overallScore: Double          // 0–100
  public var verdict: String?              // "strong_hire" | "hire" | "lean_hire" | "no_hire"
  public var summaryMarkdown: String
  public var dimensionScores: [DimensionScore]
  public var rawJSON: String               // full buddy-eval payload, future-proofing

  public init(
    id: String = UUID().uuidString.lowercased(),
    attemptId: String,
    createdAt: Date = Date(),
    overallScore: Double,
    verdict: String? = nil,
    summaryMarkdown: String,
    dimensionScores: [DimensionScore] = [],
    rawJSON: String
  ) {
    self.id = id
    self.attemptId = attemptId
    self.createdAt = createdAt
    self.overallScore = overallScore
    self.verdict = verdict
    self.summaryMarkdown = summaryMarkdown
    self.dimensionScores = dimensionScores
    self.rawJSON = rawJSON
  }
}

public struct DimensionScore: Codable, Equatable, Sendable {
  public var dimension: String   // "correctness", "complexity_analysis", "communication", ...
  public var score: Double       // 0–10
  public var maxScore: Double
  public var comment: String?

  public init(dimension: String, score: Double, maxScore: Double = 10, comment: String? = nil) {
    self.dimension = dimension
    self.score = score
    self.maxScore = maxScore
    self.comment = comment
  }
}

public struct ImprovementNote: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public var attemptId: String?
  public var topicId: String?
  public var createdAt: Date
  public var noteMarkdown: String
  public var isResolved: Bool

  public init(
    id: String = UUID().uuidString.lowercased(),
    attemptId: String? = nil,
    topicId: String? = nil,
    createdAt: Date = Date(),
    noteMarkdown: String,
    isResolved: Bool = false
  ) {
    self.id = id
    self.attemptId = attemptId
    self.topicId = topicId
    self.createdAt = createdAt
    self.noteMarkdown = noteMarkdown
    self.isResolved = isResolved
  }
}

public struct Topic: Identifiable, Codable, Equatable, Sendable {
  public let id: String          // slug PK
  public var displayName: String
  public var category: String    // "algorithms" | "data-structures" | "system-design" | "behavioral"
  public var sortOrder: Int

  public init(id: String, displayName: String, category: String, sortOrder: Int = 0) {
    self.id = id
    self.displayName = displayName
    self.category = category
    self.sortOrder = sortOrder
  }
}

public struct ScorePoint: Equatable, Sendable {
  public var date: Date
  public var overallScore: Double

  public init(date: Date, overallScore: Double) {
    self.date = date
    self.overallScore = overallScore
  }
}

/// Dashboard read model.
public struct TopicSkillStat: Sendable {
  public var topicId: String
  public var attemptCount: Int
  public var averageScore: Double?
  public var lastAttemptAt: Date?
  public var trend: [ScorePoint]           // per-attempt (date, overallScore)

  public init(
    topicId: String,
    attemptCount: Int,
    averageScore: Double? = nil,
    lastAttemptAt: Date? = nil,
    trend: [ScorePoint] = []
  ) {
    self.topicId = topicId
    self.attemptCount = attemptCount
    self.averageScore = averageScore
    self.lastAttemptAt = lastAttemptAt
    self.trend = trend
  }
}
