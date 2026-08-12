import Foundation

public enum CodingBuddyVoiceSessionContextBuilder {
  public static let maximumCharacters = 6_000
  public static let maximumTurnCharacters = 1_000

  public static func make(
    snapshot: CodingBuddyVoiceSessionSnapshot?
  ) -> String? {
    guard let snapshot else { return nil }

    var sections = [
      "Active chat: \(snapshot.name)",
      "Mode: \(snapshot.mode)",
      "Chat provider: \(snapshot.provider)",
      "Status: \(snapshot.status)",
    ]
    if let questionTitle = normalized(snapshot.questionTitle) {
      sections.append("Problem: \(questionTitle)")
    }
    if let questionPrompt = normalized(snapshot.questionPrompt) {
      sections.append("Problem statement:\n\(limited(questionPrompt))")
    }
    if let workspacePath = normalized(snapshot.workspacePath) {
      sections.append("Workspace: \(workspacePath)")
    }
    if !snapshot.recentTurns.isEmpty {
      let transcript = snapshot.recentTurns.map { turn in
        "\(turn.role.capitalized): \(limited(turn.text))"
      }.joined(separator: "\n")
      sections.append("Recent shared chat transcript:\n\(transcript)")
    }

    let result = sections.joined(separator: "\n\n")
    guard result.count > maximumCharacters else { return result }
    return String(result.prefix(maximumCharacters)) + "…"
  }

  private static func normalized(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }

  private static func limited(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > maximumTurnCharacters else { return trimmed }
    return String(trimmed.prefix(maximumTurnCharacters)) + "…"
  }
}
