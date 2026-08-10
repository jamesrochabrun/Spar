import Foundation

protocol ChatMarkdownRendering {
  func displayMarkdown(for content: String, isComplete: Bool) -> String
}

struct DefaultChatMarkdownRenderer: ChatMarkdownRendering {
  private let fenceNormalizer: ChatMarkdownFenceNormalizing

  init(fenceNormalizer: ChatMarkdownFenceNormalizing = ChatMarkdownFenceNormalizer()) {
    self.fenceNormalizer = fenceNormalizer
  }

  func displayMarkdown(for content: String, isComplete: Bool) -> String {
    let collapsed = BuddyFenceCollapser.collapse(content)
    guard !isComplete else { return collapsed }
    return fenceNormalizer.normalizedMarkdown(collapsed)
  }
}

/// Collapses ```buddy-question / ```buddy-eval structured-output fences into a
/// small chip line so raw contract JSON never clutters the chat. Unterminated
/// buddy fences (mid-stream) collapse to an in-progress chip.
enum BuddyFenceCollapser {

  private static let chips: [(language: String, chip: String, streamingChip: String)] = [
    ("buddy-question", "`📥 Question saved to bank`", "`📥 Saving question…`"),
    ("buddy-eval", "`📊 Evaluation recorded`", "`📊 Grading…`"),
    ("buddy-study-plan", "`📚 Study plan saved`", "`📚 Building study plan…`"),
    ("buddy-lesson", "`🎓 Lesson shown in the Lesson tab`", "`🎓 Preparing lesson…`"),
  ]

  static func collapse(_ markdown: String) -> String {
    guard markdown.contains("```buddy-") else { return markdown }

    var output: [String] = []
    var activeChip: (chip: String, streamingChip: String)?
    let lines = markdown.components(separatedBy: "\n")

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if let current = activeChip {
        if trimmed == "```" {
          output.append(current.chip)
          activeChip = nil
        }
        // Fence body is dropped entirely.
        continue
      }

      if let match = chips.first(where: { trimmed == "```\($0.language)" }) {
        activeChip = (match.chip, match.streamingChip)
        continue
      }

      output.append(line)
    }

    if let current = activeChip {
      output.append(current.streamingChip)
    }

    return output.joined(separator: "\n")
  }
}

protocol ChatMarkdownFenceNormalizing {
  func normalizedMarkdown(_ markdown: String) -> String
}

struct ChatMarkdownFenceNormalizer: ChatMarkdownFenceNormalizing {
  func normalizedMarkdown(_ markdown: String) -> String {
    guard let openFence = unclosedFence(in: markdown) else {
      return markdown
    }

    let newline = markdown.hasSuffix("\n") ? "" : "\n"
    return markdown + newline + String(repeating: String(openFence.character), count: openFence.length)
  }

  private func unclosedFence(in markdown: String) -> MarkdownFence? {
    var openFence: MarkdownFence?
    let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

    for line in lines {
      guard let fence = fenceMarker(in: line) else { continue }

      if let currentFence = openFence {
        if fence.character == currentFence.character && fence.length >= currentFence.length {
          openFence = nil
        }
      } else {
        openFence = fence
      }
    }

    return openFence
  }

  private func fenceMarker(in line: Substring) -> MarkdownFence? {
    let lineText = String(line)
    let indentation = lineText.prefix { $0 == " " }.count
    guard indentation <= 3 else { return nil }

    let start = lineText.dropFirst(indentation)
    guard let character = start.first, character == "`" || character == "~" else {
      return nil
    }

    let length = start.prefix { $0 == character }.count
    guard length >= 3 else { return nil }

    return MarkdownFence(character: character, length: length)
  }
}

private struct MarkdownFence: Equatable {
  let character: Character
  let length: Int
}
