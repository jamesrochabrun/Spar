import Foundation

public enum KnowledgeSourceKind: String, Codable, Sendable {
  case repository
}

public enum KnowledgeIndexStatus: String, Codable, Sendable {
  case pending
  case indexing
  case ready
  case failed
}

public struct KnowledgeSource: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let studySpaceID: String
  public let kind: KnowledgeSourceKind
  public var displayName: String
  public var rootPath: String
  public var indexStatus: KnowledgeIndexStatus
  public var indexedFileCount: Int
  public var chunkCount: Int
  public var indexedAt: Date?
  public var contentVersion: String?
  public var errorMessage: String?

  public init(
    id: String = UUID().uuidString.lowercased(),
    studySpaceID: String,
    kind: KnowledgeSourceKind = .repository,
    displayName: String,
    rootPath: String,
    indexStatus: KnowledgeIndexStatus = .pending,
    indexedFileCount: Int = 0,
    chunkCount: Int = 0,
    indexedAt: Date? = nil,
    contentVersion: String? = nil,
    errorMessage: String? = nil
  ) {
    self.id = id
    self.studySpaceID = studySpaceID
    self.kind = kind
    self.displayName = displayName
    self.rootPath = rootPath
    self.indexStatus = indexStatus
    self.indexedFileCount = indexedFileCount
    self.chunkCount = chunkCount
    self.indexedAt = indexedAt
    self.contentVersion = contentVersion
    self.errorMessage = errorMessage
  }
}
