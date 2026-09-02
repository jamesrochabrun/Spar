//
//  UntrustedPromptData.swift
//  CodingBuddyChat
//

import Foundation

/// Free-form candidate text, encoded as a JSON object so a prompt carries it
/// as data rather than as instructions the agent could be talked into
/// following.
enum UntrustedPromptData {
  static func json(key: String, value: String) -> String {
    let encoded = try? JSONSerialization.data(
      withJSONObject: [key: value],
      options: [.sortedKeys]
    )
    return encoded.flatMap { String(data: $0, encoding: .utf8) }
      ?? #"{"\#(key)":"Use the supplied text."}"#
  }
}
