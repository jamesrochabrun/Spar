//
//  LessonMarkdown.swift
//  CodingBuddyChat
//

import Foundation

/// Lesson fields are short inline markdown (a sentence or two with the odd
/// `code` span or emphasis), not documents — parsing them inline keeps the
/// author's line breaks and avoids pulling the full renderer into a card.
enum LessonMarkdown {
  static func inline(_ text: String) -> AttributedString {
    (try? AttributedString(
      markdown: text,
      options: AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
      )
    )) ?? AttributedString(text)
  }
}
