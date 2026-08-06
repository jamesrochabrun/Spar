import Foundation

public struct StudyPlan: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let studySpaceID: String
  public var title: String
  public var summary: String
  public var items: [StudyPlanItem]
  public let createdAt: Date
  public var updatedAt: Date

  public init(
    id: String,
    studySpaceID: String,
    title: String,
    summary: String,
    items: [StudyPlanItem],
    createdAt: Date = .now,
    updatedAt: Date = .now
  ) {
    self.id = id
    self.studySpaceID = studySpaceID
    self.title = title
    self.summary = summary
    self.items = items
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public var completedItemCount: Int {
    items.count(where: \.isCompleted)
  }

  public var nextIncompleteItem: StudyPlanItem? {
    items.first { !$0.isCompleted }
  }

  public var completionFraction: Double {
    guard !items.isEmpty else { return 0 }
    return Double(completedItemCount) / Double(items.count)
  }
}
