import Foundation
import Testing
@testable import CodingBuddyChat

struct CodingBuddyVoiceWorkspaceReaderTests {
  @Test
  func listsAndReadsOnlyWorkspaceTextFiles() async throws {
    let workspace = try makeWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let source = workspace.appendingPathComponent("Solution.swift")
    try Data("func twoSum() {}".utf8).write(to: source)
    let reader = CodingBuddyVoiceWorkspaceReader()

    let entries = try await reader.listEntries(
      in: workspace.path,
      relativePath: nil
    )
    let content = try await reader.readFile(
      in: workspace.path,
      relativePath: "Solution.swift",
      characterLimit: 12_000
    )

    #expect(entries == [
      CodingBuddyVoiceWorkspaceEntry(
        path: "Solution.swift",
        kind: "file",
        size: 16
      )
    ])
    #expect(content == "func twoSum() {}")
  }

  @Test
  func rejectsPathsOutsideTheWorkspace() async throws {
    let workspace = try makeWorkspace()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let reader = CodingBuddyVoiceWorkspaceReader()
    var rejected = false

    do {
      _ = try await reader.readFile(
        in: workspace.path,
        relativePath: "../outside.txt",
        characterLimit: 12_000
      )
    } catch {
      rejected = true
    }

    #expect(rejected)
  }

  private func makeWorkspace() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "CodingBuddyVoiceWorkspaceReaderTests-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: true
    )
    return url
  }
}
