import Foundation

protocol CodingProjectCommandRunning: Sendable {
  func runGit(arguments: [String], in directoryURL: URL) async throws
}
