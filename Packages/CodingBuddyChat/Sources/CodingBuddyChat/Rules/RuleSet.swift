//
//  RuleSet.swift
//  CodingBuddyChat
//
//  A house-rules document the candidate attaches to a session. Unlike a Study
//  Space — indexed source material the agent treats as untrusted evidence —
//  a rule set is authored guidance the agent follows when it generates work
//  and enforces when it reviews work.
//

import Foundation

public struct RuleSet: Identifiable, Sendable, Equatable {
  /// Stable identity across launches: the slugified file name, so a binding
  /// saved with a session still resolves after the app restarts.
  public let id: String
  /// Display name — the file name without its extension, as the user wrote it.
  public let name: String
  public let fileURL: URL
  public let characterCount: Int
  public let updatedAt: Date

  public init(
    id: String,
    name: String,
    fileURL: URL,
    characterCount: Int,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.fileURL = fileURL
    self.characterCount = characterCount
    self.updatedAt = updatedAt
  }

  /// Lowercased, hyphen-separated identity derived from a file name. Two files
  /// can never collide here because the library suffixes duplicate names on
  /// import.
  public static func identifier(forFileNamed name: String) -> String {
    let allowed = name.lowercased().map { character -> Character in
      character.isLetter || character.isNumber ? character : "-"
    }
    let collapsed = String(allowed)
      .split(separator: "-", omittingEmptySubsequences: true)
      .joined(separator: "-")
    return collapsed.isEmpty ? "rules" : collapsed
  }
}
