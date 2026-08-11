import Foundation
import Testing

struct WorkspaceChromeSourceTests {
  @Test
  func floatingAccessoryIsAttachedToEditorBeforeConsole() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/WorkspaceEditorView.swift"
    )

    let accessoryRange = try #require(
      source.range(of: ".overlay(alignment: .bottomTrailing)")
    )
    let consoleRange = try #require(source.range(of: "if isConsoleVisible"))

    #expect(accessoryRange.lowerBound < consoleRange.lowerBound)
  }

  @Test
  func sidebarUsesFlatRowsAndOnlyTheTopBarCreateControl() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarView.swift"
    )

    #expect(source.contains("rows: sidebarViewModel.sessionRows"))
    #expect(!source.contains("modeGroupSection"))
    #expect(!source.contains("requestNewSession(mode:"))

    let createControlCount = source.components(
      separatedBy: "systemImage: \"plus\""
    ).count - 1
    #expect(createControlCount == 1)
  }

  @Test
  func sessionRowsShowTheirModeAsAccessibleMetadata() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarSessionRow.swift"
    )

    #expect(source.contains("SidebarSessionModeIcon(mode: row.mode)"))
    #expect(source.contains("Text(row.mode.displayName.uppercased())"))
    #expect(source.contains("Open \\(row.mode.displayName) session"))
  }

  private func sourceContents(_ relativePath: String) throws -> String {
    let testsDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let packageDirectory = testsDirectory.deletingLastPathComponent()
    return try String(
      contentsOf: packageDirectory.appendingPathComponent(relativePath),
      encoding: .utf8
    )
  }
}
