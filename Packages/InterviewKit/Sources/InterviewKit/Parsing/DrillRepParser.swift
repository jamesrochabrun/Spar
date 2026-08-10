//
//  DrillRepParser.swift
//  InterviewKit
//
//  Contract (verbatim in prompts):
//  {"schema":"buddy-rep/v1","verdict":"correct|partial|incorrect",
//   "question_title":"...","topics":["two-pointers"],"difficulty":"medium",
//   "note":"one line on what was missing"}
//

import Foundation

public enum DrillRepParser {

  /// Parses one buddy-rep block. `index` is supplied by the caller because the
  /// run — not the model — owns rep numbering.
  public static func parse(_ block: String, index: Int) -> DrillRep? {
    guard let object = TolerantJSON.object(from: block) else { return nil }

    if let schema = object["schema"] as? String, !schema.hasPrefix("buddy-rep") {
      return nil
    }

    guard
      let rawVerdict = (object["verdict"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased(),
      let verdict = DrillVerdict(rawValue: rawVerdict)
    else { return nil }

    let difficulty = (object["difficulty"] as? String)
      .flatMap { Difficulty(rawValue: $0.lowercased()) } ?? .medium

    let title = (object["question_title"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let note = (object["note"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return DrillRep(
      index: index,
      questionTitle: (title?.isEmpty ?? true) ? nil : title,
      topicIds: (object["topics"] as? [Any])?.compactMap { $0 as? String } ?? [],
      difficulty: difficulty,
      verdict: verdict,
      note: (note?.isEmpty ?? true) ? nil : note
    )
  }
}
