//
//  QuestionBlockParser.swift
//  InterviewKit
//
//  Contract (verbatim in prompts):
//  {"schema":"buddy-question/v1","title":"...","difficulty":"medium",
//   "topics":["sliding-window"],"prompt_markdown":"...",
//   "reference_notes":"...","language_hint":"swift"}
//

import Foundation

public enum QuestionBlockParser {

  public static func parse(_ block: String, fallbackMode: SessionMode) -> Question? {
    guard let object = TolerantJSON.object(from: block) else { return nil }

    // Schema marker is advisory: accept any buddy-question/* version, and
    // tolerate its absence as long as required fields exist.
    if let schema = object["schema"] as? String, !schema.hasPrefix("buddy-question") {
      return nil
    }

    guard
      let title = (object["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !title.isEmpty,
      let promptMarkdown = object["prompt_markdown"] as? String,
      !promptMarkdown.isEmpty
    else { return nil }

    let difficulty = (object["difficulty"] as? String)
      .flatMap { Difficulty(rawValue: $0.lowercased()) } ?? .medium

    let mode = (object["mode"] as? String)
      .flatMap { SessionMode(rawValue: $0) } ?? fallbackMode

    let topics = (object["topics"] as? [Any])?.compactMap { $0 as? String } ?? []

    return Question(
      mode: mode,
      title: title,
      promptMarkdown: promptMarkdown,
      difficulty: difficulty,
      topicIds: topics,
      languageHint: object["language_hint"] as? String,
      referenceNotes: object["reference_notes"] as? String
    )
  }
}
