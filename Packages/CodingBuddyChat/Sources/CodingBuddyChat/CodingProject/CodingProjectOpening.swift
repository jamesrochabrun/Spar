import Foundation

public protocol CodingProjectOpening: Sendable {
  @MainActor
  func openProject(at projectURL: URL) async throws
}
