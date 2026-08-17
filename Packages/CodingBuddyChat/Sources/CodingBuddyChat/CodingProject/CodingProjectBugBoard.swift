import Foundation
import InterviewKit

/// One seeded defect on the bug board.
struct CodingProjectBug: Equatable, Identifiable {
  let difficulty: Difficulty
  let text: String
  /// Position within its section, so identity survives re-sorting by difficulty.
  let index: Int

  var id: Int { index }
}

/// A bug category — "UI Bugs", "Data & State Bugs", … Each one carries its own
/// easy→hard ladder, independent of every other category, so the candidate can
/// pick the area they want to practice rather than a global difficulty.
struct CodingProjectBugSection: Equatable, Identifiable {
  let title: String
  let bugs: [CodingProjectBug]

  var id: String { title }

  /// Difficulty span, for the category chip ("Easy–Hard").
  var difficultyRange: String {
    guard let lowest = bugs.map(\.difficulty).min(by: { rank($0) < rank($1) }),
          let highest = bugs.map(\.difficulty).max(by: { rank($0) < rank($1) }) else {
      return ""
    }
    return lowest == highest
      ? lowest.displayName
      : "\(lowest.displayName)–\(highest.displayName)"
  }

  private func rank(_ difficulty: Difficulty) -> Int {
    CodingProjectBugBoard.rank(difficulty)
  }
}

/// Splits a coding-project prompt into its bug board (debugging exercises) and
/// the remaining prose sections (feature exercises keep Requirements and
/// friends untouched — the board only appears when bugs were actually seeded).
enum CodingProjectBugBoard {

  static func split(
    _ sections: [CodingProjectRequirementSection]
  ) -> (board: [CodingProjectBugSection], remainder: [CodingProjectRequirementSection]) {
    var board: [CodingProjectBugSection] = []
    var remainder: [CodingProjectRequirementSection] = []

    for section in sections {
      guard isBugSection(section.title) else {
        remainder.append(section)
        continue
      }
      board.append(
        CodingProjectBugSection(title: section.title, bugs: bugs(from: section.items))
      )
    }

    return (board, remainder)
  }

  /// A heading is a bug category when it reads like one: "UI Bugs",
  /// "Performance Bugs", or the older "Bugs to Diagnose".
  static func isBugSection(_ title: String) -> Bool {
    let normalized = title.lowercased()
    return normalized.hasSuffix("bugs")
      || normalized.hasPrefix("bugs")
      || normalized.hasSuffix("defects")
  }

  /// Category name without the trailing "Bugs" — the chip says the area, the
  /// board header already says these are bugs.
  static func categoryName(_ title: String) -> String {
    let trimmed = title.trimmingCharacters(in: .whitespaces)
    guard trimmed.lowercased().hasSuffix(" bugs") else { return trimmed }
    return String(trimmed.dropLast(" bugs".count))
  }

  static func rank(_ difficulty: Difficulty) -> Int {
    switch difficulty {
    case .easy: return 0
    case .medium: return 1
    case .hard: return 2
    }
  }

  /// Bugs come back ordered low→high difficulty. Ordering is the candidate's
  /// on-ramp: a section is worth choosing only if they can see where it starts.
  private static func bugs(from items: [String]) -> [CodingProjectBug] {
    items
      .map(parseBug)
      .enumerated()
      .sorted { lhs, rhs in
        let left = rank(lhs.element.difficulty)
        let right = rank(rhs.element.difficulty)
        return left == right ? lhs.offset < rhs.offset : left < right
      }
      .enumerated()
      .map { position, entry in
        CodingProjectBug(
          difficulty: entry.element.difficulty,
          text: entry.element.text,
          index: position
        )
      }
  }

  /// Accepts `[easy] …`, `(Easy) …`, and `Easy: …`. An untagged bug is treated
  /// as medium rather than dropped — a missing tag must not hide a real defect.
  private static func parseBug(_ item: String) -> (difficulty: Difficulty, text: String) {
    let trimmed = item.trimmingCharacters(in: .whitespaces)

    for (open, close) in [("[", "]"), ("(", ")")] where trimmed.hasPrefix(open) {
      guard let end = trimmed.firstIndex(of: Character(close)) else { continue }
      let tag = trimmed[trimmed.index(after: trimmed.startIndex)..<end]
      if let difficulty = difficulty(from: String(tag)) {
        return (difficulty, remainder(of: trimmed, after: end))
      }
    }

    if let colon = trimmed.firstIndex(of: ":"),
       let difficulty = difficulty(from: String(trimmed[..<colon])) {
      return (difficulty, remainder(of: trimmed, after: colon))
    }

    return (.medium, trimmed)
  }

  private static func remainder(of text: String, after index: String.Index) -> String {
    let rest = text[text.index(after: index)...]
    return rest
      .trimmingCharacters(in: .whitespaces)
      .trimmingCharacters(in: CharacterSet(charactersIn: "—-–:"))
      .trimmingCharacters(in: .whitespaces)
  }

  private static func difficulty(from tag: String) -> Difficulty? {
    let normalized = tag
      .trimmingCharacters(in: .whitespaces)
      .trimmingCharacters(in: CharacterSet(charactersIn: "*_"))
      .lowercased()
    return Difficulty(rawValue: normalized)
  }
}
