public struct CodingBuddyVoiceTurn: Codable, Equatable, Sendable {
  public let role: String
  public let text: String

  public init(role: String, text: String) {
    self.role = role
    self.text = text
  }
}
