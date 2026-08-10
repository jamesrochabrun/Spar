import Foundation
import Testing

struct KnowledgeLibraryLayoutSourceTests {
  @Test
  func librarySheetReservesEnoughWidthForTheSourcePreview() throws {
    let librarySource = try sourceContents(
      "Sources/CodingBuddyChat/Knowledge/KnowledgeLibraryView.swift"
    )
    let sourcesSource = try sourceContents(
      "Sources/CodingBuddyChat/Knowledge/KnowledgeSourcesView.swift"
    )

    #expect(librarySource.contains("minWidth: 1120"))
    #expect(librarySource.contains("idealWidth: 1280"))
    #expect(
      librarySource.contains(
        ".navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)"
      )
    )
    #expect(sourcesSource.contains("minWidth: 260, idealWidth: 320, maxWidth: 360"))
    #expect(sourcesSource.contains("minWidth: 440"))
    #expect(sourcesSource.contains("idealWidth: 640"))
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
