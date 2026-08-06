import Foundation

public struct KnowledgeChunk: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let studySpaceID: String
  public let sourceID: String
  public let relativePath: String
  public let startLine: Int
  public let endLine: Int
  public let content: String
  public let contentHash: String

  public init(
    id: String,
    studySpaceID: String,
    sourceID: String,
    relativePath: String,
    startLine: Int,
    endLine: Int,
    content: String,
    contentHash: String
  ) {
    self.id = id
    self.studySpaceID = studySpaceID
    self.sourceID = sourceID
    self.relativePath = relativePath
    self.startLine = startLine
    self.endLine = endLine
    self.content = content
    self.contentHash = contentHash
  }

  public var locationLabel: String {
    startLine == endLine
      ? "\(relativePath):\(startLine)"
      : "\(relativePath):\(startLine)-\(endLine)"
  }
}
