import Foundation

public struct KnowledgeSearchResult: Identifiable, Equatable, Sendable {
  public let chunk: KnowledgeChunk
  public let score: Double

  public var id: String { chunk.id }

  public init(chunk: KnowledgeChunk, score: Double) {
    self.chunk = chunk
    self.score = score
  }
}

public struct KnowledgeSessionBinding: Codable, Equatable, Sendable {
  public let chatSessionID: String
  public let configuration: KnowledgeSessionConfiguration
  public let createdAt: Date

  public init(
    chatSessionID: String,
    configuration: KnowledgeSessionConfiguration,
    createdAt: Date = Date()
  ) {
    self.chatSessionID = chatSessionID
    self.configuration = configuration
    self.createdAt = createdAt
  }
}
