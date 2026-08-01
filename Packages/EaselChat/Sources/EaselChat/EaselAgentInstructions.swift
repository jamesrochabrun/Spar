//
//  EaselAgentInstructions.swift
//  EaselChat
//
//  Placeholder instructions for WP0. Replaced by BuddyAgentInstructions
//  (mode-specific interview personas) in WP3/WP4.
//

import Foundation

public enum EaselAgentInstructions {

  private static let base = """
    You are Buddy, the assistant inside CodingBuddy, a macOS interview-prep app. \
    Help the user practice coding interviews: answer questions, review code, and \
    explain concepts clearly and concisely. Do not run servers or open browsers.
    """

  public static var systemPromptPrefix: String { base }

  public static var codexDeveloperInstructionsPrefix: String { base }

  public static var apiAgentInstructionsPrefix: String { base }

  /// Wraps optional hidden context for an outgoing message. Interview-mode
  /// context (attempt, timer, hints) is added here in WP4.
  public static func appendingHiddenContext(
    _ hiddenContext: String?,
    workingDirectory: String?
  ) -> String {
    var sections: [String] = []

    if let hiddenContext, !hiddenContext.isEmpty {
      sections.append(hiddenContext)
    }

    if let workingDirectory, !workingDirectory.isEmpty {
      sections.append("Workspace directory: \(workingDirectory)")
    }

    return sections.joined(separator: "\n\n")
  }
}
