import Foundation

public enum StudyPlanBlockParser {
  public static let fenceLanguage = "buddy-study-plan"

  public static func parseBlocks(
    in message: String,
    studySpaceID: String
  ) -> [StudyPlan] {
    fencedBlocks(in: message).compactMap {
      parse($0, studySpaceID: studySpaceID)
    }
  }

  public static func parse(
    _ block: String,
    studySpaceID: String
  ) -> StudyPlan? {
    guard let object = jsonObject(from: block) else { return nil }
    if let schema = object["schema"] as? String,
       !schema.hasPrefix("buddy-study-plan/") {
      return nil
    }

    let title = nonemptyString(object["title"]) ?? "Repository Study Plan"
    let summary = nonemptyString(object["summary"]) ?? ""
    guard let rawItems = object["items"] as? [Any] else { return nil }

    var usedIDs: Set<String> = []
    var items: [StudyPlanItem] = []
    for (index, value) in rawItems.enumerated() {
      guard let item = value as? [String: Any],
            let itemTitle = nonemptyString(item["title"]) else {
        continue
      }
      let requestedID = nonemptyString(item["id"]) ?? itemTitle
      let baseID = slug(requestedID)
      let fallbackID = baseID.isEmpty ? "topic-\(index + 1)" : baseID
      var resolvedID = fallbackID
      var duplicateIndex = 2
      while usedIDs.contains(resolvedID) {
        resolvedID = "\(fallbackID)-\(duplicateIndex)"
        duplicateIndex += 1
      }
      usedIDs.insert(resolvedID)

      items.append(StudyPlanItem(
        id: resolvedID,
        section: nonemptyString(item["section"]) ?? "Repository Foundations",
        title: itemTitle,
        objective: nonemptyString(item["objective"]) ?? itemTitle,
        topics: stringArray(item["topics"]),
        sourcePaths: stringArray(item["source_paths"]),
        prerequisiteIDs: stringArray(item["prerequisite_ids"]).map(slug)
      ))
    }

    guard !items.isEmpty else { return nil }
    return StudyPlan(
      id: "study-plan-\(studySpaceID)",
      studySpaceID: studySpaceID,
      title: title,
      summary: summary,
      items: items
    )
  }

  private static func fencedBlocks(in text: String) -> [String] {
    var blocks: [String] = []
    var current: [String]?

    for line in text.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if current == nil {
        if trimmed == "```\(fenceLanguage)" {
          current = []
        }
      } else if trimmed == "```" || trimmed.hasPrefix("``` ") {
        blocks.append(current?.joined(separator: "\n") ?? "")
        current = nil
      } else {
        current?.append(line)
      }
    }

    if let current, !current.isEmpty {
      blocks.append(current.joined(separator: "\n"))
    }
    return blocks
  }

  private static func jsonObject(from raw: String) -> [String: Any]? {
    let candidates = [raw, bracedObject(in: raw)].compactMap { $0 }
    for candidate in candidates {
      for text in [candidate, removingTrailingCommas(from: candidate)] {
        guard let data = text.data(using: .utf8) else { continue }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          return object
        }
      }
    }
    return nil
  }

  private static func bracedObject(in text: String) -> String? {
    guard let start = text.firstIndex(of: "{"),
          let end = text.lastIndex(of: "}"),
          start < end else {
      return nil
    }
    return String(text[start...end])
  }

  private static func removingTrailingCommas(from text: String) -> String {
    var result = ""
    var pendingComma: String?

    for character in text {
      switch character {
      case ",":
        if let pendingComma {
          result += pendingComma
        }
        pendingComma = ","
      case " ", "\t", "\n", "\r":
        if pendingComma != nil {
          pendingComma?.append(character)
        } else {
          result.append(character)
        }
      case "}", "]":
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
    if let pendingComma {
      result += pendingComma
    }
    return result
  }

  private static func nonemptyString(_ value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func stringArray(_ value: Any?) -> [String] {
    ((value as? [Any]) ?? []).compactMap(nonemptyString)
  }

  private static func slug(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics
    let parts = value
      .lowercased()
      .components(separatedBy: allowed.inverted)
      .filter { !$0.isEmpty }
    return parts.joined(separator: "-")
  }
}
