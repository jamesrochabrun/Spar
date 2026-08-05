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
  func modeGroupPlusButtonPrecedesChevronButton() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarView.swift"
    )

    let sectionStart = try #require(source.range(of: "private func modeGroupSection"))
    let sectionEnd = try #require(
      source.range(of: "private func startFirstSessionTitle")
    )
    let section = source[sectionStart.lowerBound..<sectionEnd.lowerBound]
    let plusRange = try #require(
      section.range(of: "systemImage: \"plus\"")
    )
    let chevronRange = try #require(
      section.range(of: "systemImage: \"chevron.right\"")
    )

    #expect(plusRange.lowerBound < chevronRange.lowerBound)
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
