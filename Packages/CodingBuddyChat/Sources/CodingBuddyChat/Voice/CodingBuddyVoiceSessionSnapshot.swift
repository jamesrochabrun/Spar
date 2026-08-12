public struct CodingBuddyVoiceSessionSnapshot: Codable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let mode: String
  public let provider: String
  public let status: String
  public let questionTitle: String?
  public let questionPrompt: String?
  public let workspacePath: String?
  public let recentTurns: [CodingBuddyVoiceTurn]

  public init(
    id: String,
    name: String,
    mode: String,
    provider: String,
    status: String,
    questionTitle: String?,
    questionPrompt: String?,
    workspacePath: String?,
    recentTurns: [CodingBuddyVoiceTurn]
  ) {
    self.id = id
    self.name = name
    self.mode = mode
    self.provider = provider
    self.status = status
    self.questionTitle = questionTitle
    self.questionPrompt = questionPrompt
    self.workspacePath = workspacePath
    self.recentTurns = recentTurns
  }
}
