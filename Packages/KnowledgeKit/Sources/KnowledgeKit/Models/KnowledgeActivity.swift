import Foundation

public enum KnowledgeActivity: String, Codable, CaseIterable, Identifiable, Sendable {
  case learn
  case interview

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .learn: return "Learn"
    case .interview: return "Interview Me"
    }
  }

  public var systemImage: String {
    switch self {
    case .learn: return "book.pages"
    case .interview: return "person.wave.2"
    }
  }

  public var summary: String {
    switch self {
    case .learn:
      return "Ask questions, request explanations, and explore with citations."
    case .interview:
      return "Let Buddy lead, probe your understanding, and grade the attempt."
    }
  }
}

public enum KnowledgeSourceAccess: String, Codable, CaseIterable, Identifiable, Sendable {
  case openBook = "open_book"
  case closedBook = "closed_book"

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .openBook: return "Open Book"
    case .closedBook: return "Closed Book"
    }
  }
}

public struct KnowledgeSessionConfiguration: Codable, Equatable, Sendable {
  public let studySpaceID: String
  public let activity: KnowledgeActivity
  public let sourceAccess: KnowledgeSourceAccess

  public init(
    studySpaceID: String,
    activity: KnowledgeActivity,
    sourceAccess: KnowledgeSourceAccess = .openBook
  ) {
    self.studySpaceID = studySpaceID
    self.activity = activity
    self.sourceAccess = sourceAccess
  }
}
