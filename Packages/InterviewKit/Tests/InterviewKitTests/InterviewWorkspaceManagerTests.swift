import Foundation
import Testing
@testable import InterviewKit

struct InterviewWorkspaceManagerTests {
  @Test
  func unmanagedWorkspaceErrorUsesSparBranding() {
    let message = InterviewWorkspaceError.unmanagedPath("/tmp/outside").errorDescription

    #expect(message?.contains("Spar") == true)
    #expect(message?.contains("CodingBuddy") == false)
  }

  @Test
  func deletesWorkspaceInsideManagedRoot() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let manager = InterviewWorkspaceManager(rootDirectory: root)
    let workspacePath = try manager.createWorkspace(slug: "Delete Me", kind: .scratch)

    try manager.deleteWorkspace(atPath: workspacePath)

    #expect(!FileManager.default.fileExists(atPath: workspacePath))
  }

  @Test
  func keepsXcodeProjectsInTheirOwnManagedRoot() throws {
    let root = temporaryRoot()
    let workspaces = root.appendingPathComponent("Workspaces", isDirectory: true)
    let projects = root.appendingPathComponent("Xcode Projects", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let manager = InterviewWorkspaceManager(
      rootDirectory: workspaces,
      xcodeProjectsRootDirectory: projects
    )

    let scratchPath = try manager.createWorkspace(slug: "Array Drill", kind: .scratch)
    let projectPath = try manager.createWorkspace(slug: "Coding Project", kind: .xcodeProject)

    #expect(URL(fileURLWithPath: scratchPath).deletingLastPathComponent() == workspaces)
    #expect(URL(fileURLWithPath: projectPath).deletingLastPathComponent() == projects)
    #expect(FileManager.default.fileExists(atPath: projectPath))

    try manager.deleteWorkspace(atPath: projectPath)
    #expect(!FileManager.default.fileExists(atPath: projectPath))
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
