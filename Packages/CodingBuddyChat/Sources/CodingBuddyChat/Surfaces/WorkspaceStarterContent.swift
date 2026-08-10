import Foundation
import InterviewKit

/// Builds the candidate's initial source file from a structured question.
/// Markdown stays in the problem panel; only raw, correctly indented source
/// from language-matching fences is copied into the workspace.
enum WorkspaceStarterContent {
  static func fileName(for languageHint: String?) -> String {
    switch normalizedLanguage(languageHint) {
    case "python": "solution.py"
    case "ruby": "solution.rb"
    case "typescript": "solution.ts"
    case "javascript": "solution.js"
    case "kotlin": "Solution.kt"
    case "java": "Solution.java"
    case "cpp": "solution.cpp"
    case "c": "solution.c"
    case "go": "solution.go"
    case "rust": "solution.rs"
    default: "solution.swift"
    }
  }

  static func make(for question: Question) -> String {
    let language = normalizedLanguage(question.languageHint)
    let parsed = parse(question.promptMarkdown, language: language)
    let comment = commentPrefix(for: language)
    var lines = commentHeader(
      for: question,
      narrativeLines: parsed.narrativeLines,
      comment: comment
    )

    if !parsed.sourceBlocks.isEmpty {
      lines.append("")
      lines.append(parsed.sourceBlocks.joined(separator: "\n\n"))
    } else {
      lines.append("")
    }

    return lines.joined(separator: "\n") + "\n"
  }

  private static func normalizedLanguage(_ languageHint: String?) -> String {
    switch languageHint?.lowercased() {
    case "py": "python"
    case "rb": "ruby"
    case "ts": "typescript"
    case "js": "javascript"
    case "c++": "cpp"
    case "golang": "go"
    case .some(let language): language
    case nil: "swift"
    }
  }

  private static func commentPrefix(for language: String) -> String {
    switch language {
    case "python", "ruby": "#"
    default: "//"
    }
  }

  private static func commentHeader(
    for question: Question,
    narrativeLines: [String],
    comment: String
  ) -> [String] {
    var lines: [String] = []
    var heading = "\(question.title) — \(question.difficulty.displayName)"
    if !question.topicIds.isEmpty {
      heading += " (\(question.topicIds.joined(separator: ", ")))"
    }
    lines.append("\(comment) \(heading)")
    lines.append(comment)

    for paragraph in narrativeLines {
      for wrapped in wrap(paragraph, width: 88) {
        lines.append(wrapped.isEmpty ? comment : "\(comment) \(wrapped)")
      }
    }

    lines.append(comment)
    lines.append("\(comment) Complete the TODOs below. ⌘S saves — graded on End & Grade.")
    return lines
  }

  private static func parse(
    _ markdown: String,
    language: String
  ) -> (narrativeLines: [String], sourceBlocks: [String]) {
    let lines = markdown.components(separatedBy: "\n")
    var narrativeLines: [String] = []
    var sourceBlocks: [String] = []
    var fencedLines: [String] = []
    var fenceLanguage: String?

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if fenceLanguage == nil, let info = openingFenceInfo(from: trimmed) {
        fenceLanguage = normalizedFenceLanguage(info)
        fencedLines = []
      } else if fenceLanguage != nil, isClosingFence(trimmed) {
        if fenceLanguage == language {
          let source = fencedLines.joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
          if !source.isEmpty {
            sourceBlocks.append(source)
          }
        }
        fenceLanguage = nil
        fencedLines = []
      } else if fenceLanguage != nil {
        fencedLines.append(line)
      } else {
        narrativeLines.append(line)
      }
    }

    // An unterminated fence is malformed Markdown, so keep its body out of the
    // source file rather than risking literal prose or fence markers in code.
    return (narrativeLines, sourceBlocks)
  }

  private static func openingFenceInfo(from line: String) -> String? {
    guard line.hasPrefix("```"), line != "```" else { return nil }
    return String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
  }

  private static func isClosingFence(_ line: String) -> Bool {
    line == "```"
  }

  private static func normalizedFenceLanguage(_ info: String) -> String {
    let firstToken = info.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
    return normalizedLanguage(firstToken)
  }

  private static func wrap(_ text: String, width: Int) -> [String] {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return [""] }

    var lines: [String] = []
    var current = ""
    for word in trimmed.split(separator: " ") {
      if current.isEmpty {
        current = String(word)
      } else if current.count + word.count + 1 <= width {
        current += " \(word)"
      } else {
        lines.append(current)
        current = String(word)
      }
    }
    if !current.isEmpty {
      lines.append(current)
    }
    return lines
  }
}
