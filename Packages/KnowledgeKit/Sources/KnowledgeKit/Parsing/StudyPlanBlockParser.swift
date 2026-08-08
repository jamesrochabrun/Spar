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
    guard let object = jsonObject(from: block),
          FencedJSONBlocks.matchesSchema(object["schema"], family: "buddy-study-plan/") else {
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
    FencedJSONBlocks.blocks(language: fenceLanguage, in: text)
  }

  private static func jsonObject(from raw: String) -> [String: Any]? {
    FencedJSONBlocks.jsonObject(from: raw)
  }

  private static func nonemptyString(_ value: Any?) -> String? {
    FencedJSONBlocks.nonemptyString(value)
  }

  private static func stringArray(_ value: Any?) -> [String] {
    FencedJSONBlocks.stringArray(value)
  }

  private static func slug(_ value: String) -> String {
    FencedJSONBlocks.slug(value)
  }
}
