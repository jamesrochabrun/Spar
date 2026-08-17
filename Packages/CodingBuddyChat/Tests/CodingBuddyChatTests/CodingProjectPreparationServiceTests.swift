import Foundation
import Testing
@testable import CodingBuddyChat

struct CodingProjectPreparationServiceTests {
  @Test
  func importedProjectIsCopiedWithoutOldGitOrBuildArtifactsAndGetsABaseline() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "Source", directoryHint: .isDirectory)
    let workspace = root.appending(path: "Workspace", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

    try makeDirectory(source.appending(path: "Sample.xcodeproj", directoryHint: .isDirectory))
    try "// project".write(
      to: source.appending(path: "Sample.xcodeproj/project.pbxproj"),
      atomically: true,
      encoding: .utf8
    )
    try makeDirectory(source.appending(path: "Sample", directoryHint: .isDirectory))
    try "import SwiftUI".write(
      to: source.appending(path: "Sample/App.swift"),
      atomically: true,
      encoding: .utf8
    )
    try makeDirectory(source.appending(path: ".git", directoryHint: .isDirectory))
    try "old".write(
      to: source.appending(path: ".git/config"),
      atomically: true,
      encoding: .utf8
    )
    try makeDirectory(source.appending(path: "DerivedData", directoryHint: .isDirectory))
    try "cache".write(
      to: source.appending(path: "DerivedData/cache"),
      atomically: true,
      encoding: .utf8
    )

    let runner = RecordingCodingProjectCommandRunner()
    let service = CodingProjectPreparationService(commandRunner: runner)
    try await service.prepareImportedProject(from: source, in: workspace)

    #expect(FileManager.default.fileExists(atPath: workspace.appending(path: "Sample.xcodeproj/project.pbxproj").path))
    #expect(FileManager.default.fileExists(atPath: workspace.appending(path: "Sample/App.swift").path))
    #expect(!FileManager.default.fileExists(atPath: workspace.appending(path: ".git/config").path))
    #expect(!FileManager.default.fileExists(atPath: workspace.appending(path: "DerivedData/cache").path))

    let gitIgnore = try String(
      contentsOf: workspace.appending(path: ".gitignore"),
      encoding: .utf8
    )
    #expect(gitIgnore.contains("DerivedData/"))
    #expect(gitIgnore.contains("xcuserdata/"))

    let calls = await runner.recordedCalls()
    #expect(calls.count == 3)
    #expect(calls[0] == ["init"])
    #expect(calls[1] == ["add", "--all"])
    #expect(calls[2].contains("commit"))
    #expect(calls[2].contains("Spar interview baseline"))
  }

  @Test
  func folderWithoutAnXcodeContainerIsRejectedBeforeCopying() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "Source", directoryHint: .isDirectory)
    let workspace = root.appending(path: "Workspace", directoryHint: .isDirectory)
    try makeDirectory(source)
    try "import SwiftUI".write(
      to: source.appending(path: "App.swift"),
      atomically: true,
      encoding: .utf8
    )

    let service = CodingProjectPreparationService(
      commandRunner: RecordingCodingProjectCommandRunner()
    )
    await #expect(throws: CodingProjectPreparationError.xcodeProjectNotFound) {
      try await service.prepareImportedProject(from: source, in: workspace)
    }
  }

  @Test
  func defaultPreparerCreatesARealGitRepositoryAndCommit() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "Source", directoryHint: .isDirectory)
    let workspace = root.appending(path: "Workspace", directoryHint: .isDirectory)
    try makeDirectory(source.appending(path: "Sample.xcodeproj", directoryHint: .isDirectory))
    try "// project".write(
      to: source.appending(path: "Sample.xcodeproj/project.pbxproj"),
      atomically: true,
      encoding: .utf8
    )
    try "import SwiftUI".write(
      to: source.appending(path: "App.swift"),
      atomically: true,
      encoding: .utf8
    )

    try await CodingProjectPreparationService().prepareImportedProject(
      from: source,
      in: workspace
    )

    #expect(FileManager.default.fileExists(atPath: workspace.appending(path: ".git/HEAD").path))
    #expect(FileManager.default.fileExists(atPath: workspace.appending(path: ".git/index").path))
    #expect(FileManager.default.fileExists(atPath: workspace.appending(path: ".git/logs/HEAD").path))
  }

  @Test
  func locatorPrefersTheShallowWorkspaceOverNestedProjects() throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = root.appending(path: "Sample.xcworkspace", directoryHint: .isDirectory)
    let nestedProject = root.appending(path: "Modules/Nested.xcodeproj", directoryHint: .isDirectory)
    try makeDirectory(workspace)
    try makeDirectory(nestedProject)

    #expect(
      CodingProjectLocator.projectURL(in: root)?.resolvingSymlinksInPath()
        == workspace.resolvingSymlinksInPath()
    )
  }

  @Test @MainActor
  func xcodeOpenerRejectsAMissingProjectBeforeLaunching() async {
    let missingProject = temporaryDirectory()
      .appending(path: "Missing.xcodeproj", directoryHint: .isDirectory)

    await #expect(throws: CodingProjectOpenError.projectNotFound) {
      try await SystemCodingProjectOpener().openProject(at: missingProject)
    }
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appending(path: "CodingProjectPreparationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
  }

  private func makeDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }
}

private actor RecordingCodingProjectCommandRunner: CodingProjectCommandRunning {
  private var calls: [[String]] = []

  func runGit(arguments: [String], in directoryURL: URL) async throws {
    calls.append(arguments)
  }

  func recordedCalls() -> [[String]] {
    calls
  }
}
