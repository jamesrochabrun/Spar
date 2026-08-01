//
//  RubricEvaluationParser.swift
//  InterviewKit
//
//  Contract (verbatim in prompts):
//  {"schema":"buddy-eval/v1","overall_score":72,"verdict":"lean_hire",
//   "dimensions":[{"id":"correctness","score":7,"max":10,"comment":"..."}],
//   "summary_markdown":"...",
//   "improvement_notes":[{"topic":"dynamic-programming","note":"..."}]}
//

import Foundation

public enum RubricEvaluationParser {

  public static func parse(_ block: String, attemptId: String) -> CapturedEvaluation? {
    guard let object = TolerantJSON.object(from: block) else { return nil }

    if let schema = object["schema"] as? String, !schema.hasPrefix("buddy-eval") {
      return nil
    }

    guard let overallScore = doubleValue(object["overall_score"]) else { return nil }

    let summaryMarkdown = (object["summary_markdown"] as? String) ?? ""

    var dimensions: [DimensionScore] = []
    for entry in (object["dimensions"] as? [Any]) ?? [] {
      guard let dict = entry as? [String: Any] else { continue }
      let id = (dict["id"] as? String) ?? (dict["dimension"] as? String)
      guard let dimension = id, let score = doubleValue(dict["score"]) else { continue }
      dimensions.append(DimensionScore(
        dimension: dimension,
        score: score,
        maxScore: doubleValue(dict["max"]) ?? doubleValue(dict["max_score"]) ?? 10,
        comment: dict["comment"] as? String
      ))
    }

    let evaluation = RubricEvaluation(
      attemptId: attemptId,
      overallScore: min(100, max(0, overallScore)),
      verdict: object["verdict"] as? String,
      summaryMarkdown: summaryMarkdown,
      dimensionScores: dimensions,
      rawJSON: block
    )

    var notes: [ImprovementNote] = []
    for entry in (object["improvement_notes"] as? [Any]) ?? [] {
      guard let dict = entry as? [String: Any],
            let note = dict["note"] as? String, !note.isEmpty else { continue }
      notes.append(ImprovementNote(
        attemptId: attemptId,
        topicId: dict["topic"] as? String,
        noteMarkdown: note
      ))
    }

    return CapturedEvaluation(evaluation: evaluation, notes: notes)
  }

  private static func doubleValue(_ value: Any?) -> Double? {
    if let double = value as? Double { return double }
    if let int = value as? Int { return Double(int) }
    if let number = value as? NSNumber { return number.doubleValue }
    if let string = value as? String { return Double(string) }
    return nil
  }
}
