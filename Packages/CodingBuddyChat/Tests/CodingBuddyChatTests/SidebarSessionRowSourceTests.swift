import Foundation
import Testing

struct SidebarSessionRowSourceTests {
  @Test
  func selectedSessionUsesColorShapeWeightAndAccessibilityCues() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarSessionRow.swift"
    )

    #expect(source.contains("Palette.selectionAccent(for: colorScheme)"))
    #expect(source.contains("isSelected ? selectionAccent.opacity(0.65)"))
    #expect(source.contains(".overlay(alignment: .leading)"))
    #expect(source.contains(".weight(isSelected ? .semibold : .regular)"))
    #expect(source.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
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
