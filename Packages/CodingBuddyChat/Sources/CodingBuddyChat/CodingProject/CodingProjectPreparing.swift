import Foundation

public protocol CodingProjectPreparing: Sendable {
  /// Copies an imported project into the managed Xcode projects directory and commits a clean Git baseline.
  func prepareImportedProject(from sourceURL: URL, in workspaceURL: URL) async throws
}
