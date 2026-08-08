import Foundation

/// Shared extraction for the app's fenced-JSON agent contracts
/// (`buddy-study-plan`, `buddy-lesson`).
///
/// Models emit these blocks inside markdown fences and routinely add trailing
/// commas, wrap the object in stray prose, or close the fence with `` ``` ``
/// followed by a language hint. Parsing is deliberately forgiving about all of
/// that, and strict only about the JSON object itself.
enum FencedJSONBlocks {

  /// Bodies of every ```` ```<language> ```` fence in `text`, outermost fence
  /// content only. An unterminated final fence still yields its content so a
  /// truncated stream is not silently dropped.
  static func blocks(language: String, in text: String) -> [String] {
    var blocks: [String] = []
    var current: [String]?

    for line in text.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if current == nil {
        if trimmed == "```\(language)" {
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

  static func jsonObject(from raw: String) -> [String: Any]? {
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

  /// True when `schema` is absent (tolerated) or names the expected family.
  static func matchesSchema(_ value: Any?, family: String) -> Bool {
    guard let schema = value as? String else { return true }
    return schema.hasPrefix(family)
  }

  static func nonemptyString(_ value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func stringArray(_ value: Any?) -> [String] {
    ((value as? [Any]) ?? []).compactMap(nonemptyString)
  }

  /// Accepts both JSON numbers and numeric strings — small local models often
  /// quote integers.
  static func int(_ value: Any?) -> Int? {
    if let number = value as? Int { return number }
    if let number = value as? Double { return Int(number) }
    if let string = nonemptyString(value) { return Int(string) }
    return nil
  }

  static func bool(_ value: Any?) -> Bool? {
    if let flag = value as? Bool { return flag }
    guard let string = nonemptyString(value)?.lowercased() else { return nil }
    if ["true", "yes", "1"].contains(string) { return true }
    if ["false", "no", "0"].contains(string) { return false }
    return nil
  }

  static func slug(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics
    let parts = value
      .lowercased()
      .components(separatedBy: allowed.inverted)
      .filter { !$0.isEmpty }
    return parts.joined(separator: "-")
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
}
