import Foundation

public struct ChatInputDraftRequest: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let text: String

  public init(id: UUID = UUID(), text: String) {
    self.id = id
    self.text = text
  }

  public func merging(into existingText: String) -> String {
    let existing = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
    let incoming = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !existing.isEmpty else { return incoming }
    guard !incoming.isEmpty else { return existing }
    return existing + " " + incoming
  }
}
