//
//  RuleContext.swift
//  CodingBuddyChat
//
//  The value the prompt layer consumes: resolved rule bodies, already capped
//  and sanitized. Deliberately free of file/IO types so BuddyAgentInstructions
//  stays a pure string builder and stays testable without a filesystem.
//

import Foundation

public struct RuleContext: Sendable, Equatable {

  public struct Entry: Sendable, Equatable {
    public let name: String
    public let body: String

    public init(name: String, body: String) {
      self.name = name
      self.body = body
    }
  }

  /// A single rule set can crowd out the mode prompt and the retrieved
  /// evidence, so each one is capped and the combined budget is capped again.
  public static let maximumCharactersPerSet = 8_000
  public static let maximumTotalCharacters = 16_000
  /// Below this a truncated tail is noise rather than guidance, so the entry
  /// is dropped instead of being cut to a fragment.
  private static let minimumUsefulCharacters = 200

  public static let empty = RuleContext(entries: [])

  public let entries: [Entry]

  public init(entries: [Entry]) {
    self.entries = entries
  }

  public var isEmpty: Bool { entries.isEmpty }

  public var names: [String] { entries.map(\.name) }

  /// Builds a context from raw file contents, dropping empties and applying
  /// the per-set and total budgets in order.
  public static func make(from candidates: [(name: String, body: String)]) -> RuleContext {
    var remaining = maximumTotalCharacters
    var entries: [Entry] = []

    for candidate in candidates {
      let body = sanitizedBody(candidate.body)
      guard !body.isEmpty else { continue }
      guard remaining >= minimumUsefulCharacters else { break }

      let budget = min(maximumCharactersPerSet, remaining)
      let limited = body.count > budget
        ? String(body.prefix(budget)) + "\n…[rules truncated]"
        : body

      entries.append(Entry(name: sanitizedName(candidate.name), body: limited))
      remaining -= min(body.count, budget)
    }

    return RuleContext(entries: entries)
  }

  /// Each set rendered as its own delimited block. The delimiter is stripped
  /// from the body above, so a rules file cannot close the block early and
  /// smuggle text back into the surrounding instructions.
  public var blocks: String {
    entries
      .map { #"<buddy-rules name="\#($0.name)">\#n\#($0.body)\#n</buddy-rules>"# }
      .joined(separator: "\n\n")
  }

  private static func sanitizedName(_ name: String) -> String {
    let cleaned = name
      .replacingOccurrences(of: "\"", with: "")
      .replacingOccurrences(of: "<", with: "")
      .replacingOccurrences(of: ">", with: "")
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "rules" : String(cleaned.prefix(120))
  }

  private static func sanitizedBody(_ body: String) -> String {
    body
      .replacingOccurrences(of: "</buddy-rules>", with: "[/buddy-rules]")
      .replacingOccurrences(of: "<buddy-rules", with: "[buddy-rules")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
