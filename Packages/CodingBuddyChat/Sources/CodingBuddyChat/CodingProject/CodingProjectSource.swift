import Foundation

/// Where a Coding Project session gets its starter Xcode project.
public enum CodingProjectSource: Equatable, Sendable {
  case generated
  case imported(URL)
}
