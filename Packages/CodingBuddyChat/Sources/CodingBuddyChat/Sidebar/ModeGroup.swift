//
//  ModeGroup.swift
//  CodingBuddyChat
//

import ClaudeCodeCore
import Foundation
import InterviewKit

/// One sidebar row: a stored chat session joined with its interview attempt
/// (when one exists), the question title, and the rubric score.
public struct AttemptRow: Identifiable {
  public let session: StoredSession
  public let attempt: InterviewAttempt?
  public let questionTitle: String?
  public let overallScore: Double?

  public var id: String { session.id }

  /// The interview mode shown in the flat sidebar row. Legacy chats that do
  /// not have an interview attempt remain available as Practice sessions.
  public var mode: SessionMode { attempt?.mode ?? .practice }

  public init(
    session: StoredSession,
    attempt: InterviewAttempt? = nil,
    questionTitle: String? = nil,
    overallScore: Double? = nil
  ) {
    self.session = session
    self.attempt = attempt
    self.questionTitle = questionTitle
    self.overallScore = overallScore
  }

  /// Row title: question title beats the raw first message.
  public var displayTitle: String {
    if let questionTitle, !questionTitle.isEmpty { return questionTitle }
    if !session.firstUserMessage.isEmpty { return session.firstUserMessage }
    return "New Session"
  }

  /// Joins stored chat sessions with their interview metadata and returns one
  /// globally recent list for the sidebar.
  public static func rows(
    attempts: [InterviewAttempt],
    sessions: [StoredSession],
    questionTitlesById: [String: String],
    scoresByAttemptId: [String: Double]
  ) -> [AttemptRow] {
    let attemptsByChatSession: [String: InterviewAttempt] = attempts.reduce(into: [:]) { result, attempt in
      guard let chatSessionId = attempt.chatSessionId else { return }
      // Newest attempt wins when several link the same chat session.
      if let existing = result[chatSessionId], existing.startedAt > attempt.startedAt { return }
      result[chatSessionId] = attempt
    }

    return sessions
      .map { session in
        let attempt = attemptsByChatSession[session.id]
        let questionTitle = attempt?.questionId.flatMap { questionTitlesById[$0] }
        let score = attempt.flatMap { scoresByAttemptId[$0.id] }
        return AttemptRow(
          session: session,
          attempt: attempt,
          questionTitle: questionTitle,
          overallScore: score
        )
      }
      .sorted { lhs, rhs in
        if lhs.session.lastAccessedAt != rhs.session.lastAccessedAt {
          return lhs.session.lastAccessedAt > rhs.session.lastAccessedAt
        }
        return lhs.session.createdAt > rhs.session.createdAt
      }
  }
}

/// Sidebar group per interview mode, sessions sorted by started/accessed desc.
public struct ModeGroup: Identifiable {
  public let mode: SessionMode
  public var rows: [AttemptRow]
  public var isExpanded: Bool

  public var id: String { mode.rawValue }
  public var displayName: String { mode.displayName }
  public var systemImage: String { mode.systemImage }

  public init(mode: SessionMode, rows: [AttemptRow], isExpanded: Bool = true) {
    self.mode = mode
    self.rows = rows
    self.isExpanded = isExpanded
  }

  /// Fixed sidebar order for the six interview and study modes.
  public static let displayOrder: [SessionMode] = [
    .mockInterview, .codingProject, .drill, .practice, .systemDesign, .behavioral,
  ]

  /// Joins attempts with stored sessions and buckets them by mode. Sessions
  /// with no attempt land in the Practice group (legacy chats).
  public static func groups(
    attempts: [InterviewAttempt],
    sessions: [StoredSession],
    questionTitlesById: [String: String],
    scoresByAttemptId: [String: Double],
    previousExpansion: [String: Bool] = [:]
  ) -> [ModeGroup] {
    let rowsByMode = Dictionary(grouping: AttemptRow.rows(
      attempts: attempts,
      sessions: sessions,
      questionTitlesById: questionTitlesById,
      scoresByAttemptId: scoresByAttemptId
    ), by: \.mode)

    return displayOrder.map { mode in
      return ModeGroup(
        mode: mode,
        rows: rowsByMode[mode] ?? [],
        isExpanded: previousExpansion[mode.rawValue] ?? true
      )
    }
  }
}
