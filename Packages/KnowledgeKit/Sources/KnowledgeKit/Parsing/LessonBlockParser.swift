import Foundation

/// Parses ```` ```buddy-lesson ```` fences into `Lesson` values.
///
/// The agent emits one block per teaching turn. Everything except "there is
/// something to show the learner" is optional: a turn that only carries
/// feedback (the item wrapped up) is as valid as one that only carries a task
/// (the item's first turn).
public enum LessonBlockParser {
  public static let fenceLanguage = "buddy-lesson"
  private static let schemaFamily = "buddy-lesson/"

  public static func parseBlocks(in message: String) -> [Lesson] {
    FencedJSONBlocks.blocks(language: fenceLanguage, in: message).compactMap(parse)
  }

  public static func parse(_ block: String) -> Lesson? {
    guard let object = FencedJSONBlocks.jsonObject(from: block),
          FencedJSONBlocks.matchesSchema(object["schema"], family: schemaFamily) else {
      return nil
    }

    let scenario = FencedJSONBlocks.nonemptyString(object["scenario_markdown"]) ?? ""
    let inspectSteps = FencedJSONBlocks.stringArray(object["inspect_steps"])
    let feedback = FencedJSONBlocks.nonemptyString(object["feedback_markdown"])
    let teaches = FencedJSONBlocks.nonemptyString(object["teaches_markdown"])
    let outcome = FencedJSONBlocks.nonemptyString(object["outcome"]) ?? ""

    // A block with no task, no feedback, and no outcome has nothing to render;
    // treating it as a miss lets the repair directive ask for a real one.
    guard !scenario.isEmpty || !inspectSteps.isEmpty || feedback != nil || !outcome.isEmpty else {
      return nil
    }

    let step = max(1, FencedJSONBlocks.int(object["step"]) ?? 1)
    let totalSteps = max(step, FencedJSONBlocks.int(object["total_steps"]) ?? step)

    return Lesson(
      itemID: FencedJSONBlocks.nonemptyString(object["item_id"]).map(FencedJSONBlocks.slug) ?? "",
      itemTitle: FencedJSONBlocks.nonemptyString(object["item_title"]) ?? "",
      step: step,
      totalSteps: totalSteps,
      outcome: outcome,
      whyMarkdown: FencedJSONBlocks.nonemptyString(object["why_markdown"]) ?? "",
      source: parseSource(object["source"]),
      scenarioMarkdown: scenario,
      inspectSteps: inspectSteps,
      replyScaffold: FencedJSONBlocks.nonemptyString(object["reply_scaffold"]) ?? "",
      feedbackMarkdown: feedback,
      teachesMarkdown: teaches,
      isItemComplete: FencedJSONBlocks.bool(object["item_complete"]) ?? false
    )
  }

  /// Accepts the documented object form and the shorthand a model sometimes
  /// falls back to (`"source": "Sources/App.swift:112-160"`).
  private static func parseSource(_ value: Any?) -> Lesson.SourceReference? {
    if let object = value as? [String: Any] {
      guard let path = FencedJSONBlocks.nonemptyString(object["path"]) else { return nil }
      return Lesson.SourceReference(
        path: path,
        locator: FencedJSONBlocks.nonemptyString(object["locator"]) ?? "",
        chunkID: FencedJSONBlocks.nonemptyString(object["chunk_id"])
      )
    }

    guard let raw = FencedJSONBlocks.nonemptyString(value) else { return nil }
    // Split a trailing ":<locator>" only when it looks like one — a Windows
    // drive letter or a bare path must survive intact.
    guard let separator = raw.lastIndex(of: ":"), separator > raw.startIndex else {
      return Lesson.SourceReference(path: raw)
    }
    let path = String(raw[raw.startIndex..<separator])
    let locator = String(raw[raw.index(after: separator)...])
      .trimmingCharacters(in: .whitespaces)
    guard !path.isEmpty, !locator.isEmpty else {
      return Lesson.SourceReference(path: raw)
    }
    return Lesson.SourceReference(path: path, locator: locator)
  }
}
