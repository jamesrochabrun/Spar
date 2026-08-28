//
//  SessionFocus.swift
//  CodingBuddyChat
//

import Foundation

/// The candidate's free-text description of what a session should cover — a
/// domain, project, or topic to be tested on (e.g. a system-design session on
/// a ride-sharing product, or drills on Swift concurrency). Available for
/// every mode at session start and woven into the session prompt, unlike
/// `CodingProjectBrief`, which only shapes the coding-project kickoff turn.
enum SessionFocus {
  static let maximumCharacterCount = 1_000

  static func limitedInput(_ value: String) -> String {
    String(value.prefix(maximumCharacterCount))
  }

  static func normalized(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = limitedInput(value).trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
