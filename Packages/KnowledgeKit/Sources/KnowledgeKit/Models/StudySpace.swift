import Foundation

public struct StudySpace: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public var name: String
  public let createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString.lowercased(),
    name: String,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
