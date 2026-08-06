import Foundation

public struct StudyPlanItem: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public var section: String
  public var title: String
  public var objective: String
  public var topics: [String]
  public var sourcePaths: [String]
  public var prerequisiteIDs: [String]
  public var isCompleted: Bool
  public var completedAt: Date?

  public init(
    id: String,
    section: String,
    title: String,
    objective: String,
    topics: [String] = [],
    sourcePaths: [String] = [],
    prerequisiteIDs: [String] = [],
    isCompleted: Bool = false,
    completedAt: Date? = nil
  ) {
    self.id = id
    self.section = section
    self.title = title
    self.objective = objective
    self.topics = topics
    self.sourcePaths = sourcePaths
    self.prerequisiteIDs = prerequisiteIDs
    self.isCompleted = isCompleted
    self.completedAt = completedAt
  }
}
