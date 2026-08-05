import Foundation
import Testing
@testable import InterviewKit

struct InterviewWorkspaceManagerTests {
  @Test
  func deletesWorkspaceInsideManagedRoot() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let manager = InterviewWorkspaceManager(rootDirectory: root)
    let workspacePath = try manager.createWorkspace(slug: "Delete Me")

    try manager.deleteWorkspace(atPath: workspacePath)

    #expect(!FileManager.default.fileExists(atPath: workspacePath))
  }

  @Test
  func refusesToDeleteOutsideManagedRoot() throws {
    let root = temporaryRoot()
    let outside = root
      .deletingLastPathComponent()
      .appendingPathComponent("Outside-\(UUID().uuidString)", isDirectory: true)
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: outside)
    }
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    let manager = InterviewWorkspaceManager(rootDirectory: root)

    #expect(throws: InterviewWorkspaceError.self) {
      try manager.deleteWorkspace(atPath: outside.path)
    }
    #expect(FileManager.default.fileExists(atPath: outside.path))
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "InterviewWorkspaceManagerTests-\(UUID().uuidString)",
        isDirectory: true
      )
  }
}
