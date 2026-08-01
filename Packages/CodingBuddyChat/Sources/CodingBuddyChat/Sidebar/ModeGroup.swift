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

  /// Fixed sidebar order: Mock, Drills, Practice, System Design, Behavioral.
  public static let displayOrder: [SessionMode] = [
    .mockInterview, .drill, .practice, .systemDesign, .behavioral,
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
    let attemptsByChatSession: [String: InterviewAttempt] = attempts.reduce(into: [:]) { result, attempt in
      guard let chatSessionId = attempt.chatSessionId else { return }
      // Newest attempt wins when several link the same chat session.
      if let existing = result[chatSessionId], existing.startedAt > attempt.startedAt { return }
      result[chatSessionId] = attempt
    }

    var rowsByMode: [SessionMode: [AttemptRow]] = [:]
    for session in sessions {
      let attempt = attemptsByChatSession[session.id]
      let mode = attempt?.mode ?? .practice
      let questionTitle = attempt?.questionId.flatMap { questionTitlesById[$0] }
      let score = attempt.flatMap { scoresByAttemptId[$0.id] }
      rowsByMode[mode, default: []].append(AttemptRow(
        session: session,
        attempt: attempt,
        questionTitle: questionTitle,
        overallScore: score
      ))
    }

    return displayOrder.map { mode in
      let rows = (rowsByMode[mode] ?? []).sorted { lhs, rhs in
        let lhsDate = lhs.attempt?.startedAt ?? lhs.session.lastAccessedAt
        let rhsDate = rhs.attempt?.startedAt ?? rhs.session.lastAccessedAt
        return lhsDate > rhsDate
      }
      return ModeGroup(
        mode: mode,
        rows: rows,
        isExpanded: previousExpansion[mode.rawValue] ?? true
      )
    }
  }
}
