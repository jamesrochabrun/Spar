//
//  StructuredBlockCapture.swift
//  InterviewKit
//
//  Parser hub for the fenced-JSON contracts the agent emits in-transcript:
//
//  ```buddy-question
//  {"schema":"buddy-question/v1","title":"...","difficulty":"medium", ...}
//  ```
//  ```buddy-eval
//  {"schema":"buddy-eval/v1","overall_score":72, ...}
//  ```
//

import Foundation

public enum BuddyFence {
  public static let question = "buddy-question"
  public static let eval = "buddy-eval"
  public static let rep = "buddy-rep"

  /// Extracts the contents of every ```<language> fence in `text`, in order.
  public static func fencedBlocks(in text: String, language: String) -> [String] {
    var blocks: [String] = []
    let lines = text.components(separatedBy: "\n")
    var current: [String]?

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if current == nil {
        if trimmed == "```\(language)" {
          current = []
        }
      } else if trimmed == "```" || trimmed.hasPrefix("``` ") {
        blocks.append(current!.joined(separator: "\n"))
        current = nil
      } else {
        current?.append(line)
      }
    }

    // Unterminated fence at end of message: still capture it — streaming
    // finalization can drop the closing backticks.
    if let current, !current.isEmpty {
      blocks.append(current.joined(separator: "\n"))
    }

    return blocks
  }

  /// True when the message contains at least one buddy-* fence marker.
  public static func containsBuddyFence(_ text: String) -> Bool {
    text.contains("```\(question)") || text.contains("```\(eval)") || text.contains("```\(rep)")
  }
}

public struct CapturedQuestion: Sendable {
  public let question: Question
}

public struct CapturedEvaluation: Sendable {
  public let evaluation: RubricEvaluation
  public let notes: [ImprovementNote]
}

public struct CapturedDrillRep: Sendable {
  public let rep: DrillRep
}

public enum StructuredBlockCaptureResult: Sendable {
  case question(CapturedQuestion)
  case evaluation(CapturedEvaluation)
  case drillRep(CapturedDrillRep)
}

/// Stateless entry point: feed each finalized assistant message through
/// `capture`, get back any parsed structured blocks.
public enum StructuredBlockCapture {

  /// Parses every buddy-rep, buddy-question, and buddy-eval fence in the
  /// message. The last buddy-eval fence wins (repair turns re-emit the block).
  ///
  /// `nextRepIndex` is the run's own counter: a drill turn reports the verdict
  /// for the rep just finished before presenting the next problem, so reps are
  /// captured ahead of questions.
  public static func capture(
    messageText: String,
    mode: SessionMode,
    attemptId: String?,
    nextRepIndex: Int = 1
  ) -> [StructuredBlockCaptureResult] {
    var results: [StructuredBlockCaptureResult] = []

    if mode == .drill {
      var index = nextRepIndex
      for block in BuddyFence.fencedBlocks(in: messageText, language: BuddyFence.rep) {
        if let rep = DrillRepParser.parse(block, index: index) {
          results.append(.drillRep(CapturedDrillRep(rep: rep)))
          index += 1
        }
      }
    }

    for block in BuddyFence.fencedBlocks(in: messageText, language: BuddyFence.question) {
      if let question = QuestionBlockParser.parse(block, fallbackMode: mode) {
        results.append(.question(CapturedQuestion(question: question)))
      }
    }

    if let attemptId {
      let evalBlocks = BuddyFence.fencedBlocks(in: messageText, language: BuddyFence.eval)
      if let lastBlock = evalBlocks.last,
         let captured = RubricEvaluationParser.parse(lastBlock, attemptId: attemptId) {
        results.append(.evaluation(captured))
      }
    }

    return results
  }
}

// MARK: - Tolerant JSON

enum TolerantJSON {
  /// Decodes a JSON object, tolerating trailing commas and surrounding prose.
  static func object(from raw: String) -> [String: Any]? {
    let candidates = [raw, extractBracedObject(from: raw)].compactMap { $0 }
    for candidate in candidates {
      for text in [candidate, removeTrailingCommas(from: candidate)] {
        if let data = text.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          return object
        }
      }
    }
    return nil
  }

  /// Grabs the outermost {...} span so stray prose around the JSON is ignored.
  private static func extractBracedObject(from text: String) -> String? {
    guard let start = text.firstIndex(of: "{"),
          let end = text.lastIndex(of: "}"),
          start < end else { return nil }
    return String(text[start...end])
  }

  /// Removes ",}"/",]" sequences (with whitespace) that strict JSON rejects.
  private static func removeTrailingCommas(from text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)
    var pendingComma: String?

    for character in text {
      switch character {
      case ",":
        if let pending = pendingComma { result += pending }
        pendingComma = ","
      case " ", "\t", "\n", "\r":
        if pendingComma != nil {
          pendingComma? += String(character)
        } else {
          result.append(character)
        }
      case "}", "]":
        // Drop the pending comma (and its trailing whitespace) entirely.
        pendingComma = nil
        result.append(character)
      default:
        if let pending = pendingComma {
          result += pending
          pendingComma = nil
        }
        result.append(character)
      }
    }
    if let pending = pendingComma { result += pending }
    return result
  }
}
