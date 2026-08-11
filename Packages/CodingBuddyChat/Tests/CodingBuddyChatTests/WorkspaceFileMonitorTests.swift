import Foundation
import Testing

@testable import CodingBuddyChat

@Suite("Workspace file monitoring")
struct WorkspaceFileMonitorTests {
  @Test
  func directorySnapshotDetectsAnAtomicFileReplacement() throws {
    let workspaceURL = try makeTemporaryWorkspace()
    defer { try? FileManager.default.removeItem(at: workspaceURL) }
    let fileURL = workspaceURL.appendingPathComponent("solution.swift")
    try "let value = 1\n".write(to: fileURL, atomically: true, encoding: .utf8)
    let original = WorkspaceDirectorySnapshot.capture(at: workspaceURL)

    try "let answer = 42\n".write(to: fileURL, atomically: true, encoding: .utf8)
    let updated = WorkspaceDirectorySnapshot.capture(at: workspaceURL)

    #expect(updated != original)
  }

  @Test
  func monitorEmitsAfterAWorkspaceFileChanges() async throws {
    let workspaceURL = try makeTemporaryWorkspace()
    defer { try? FileManager.default.removeItem(at: workspaceURL) }
    let fileURL = workspaceURL.appendingPathComponent("solution.swift")
    try "let value = 1\n".write(to: fileURL, atomically: true, encoding: .utf8)

    let monitor = PollingWorkspaceFileMonitor(pollInterval: .milliseconds(15))
    let changes = monitor.changes(in: workspaceURL)
    try await Task.sleep(for: .milliseconds(40))
    try "let value = 2\n".write(to: fileURL, atomically: true, encoding: .utf8)

    let detectedChange = await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        for await _ in changes {
          return true
        }
        return false
      }
      group.addTask {
        try? await Task.sleep(for: .seconds(1))
        return false
      }

      let firstResult = await group.next() ?? false
      group.cancelAll()
      return firstResult
    }

    #expect(detectedChange)
  }

  private func makeTemporaryWorkspace() throws -> URL {
    let workspaceURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodingBuddyWorkspaceMonitorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    return workspaceURL
  }
}
