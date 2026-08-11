import Foundation
import Testing

struct SidebarSessionRowSourceTests {
  @Test
  func selectedSessionUsesSurfaceShapeAndAccessibilityCues() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarSessionRow.swift"
    )

    #expect(source.contains("Palette.running.opacity"))
    #expect(source.contains("accessibilityDifferentiateWithoutColor"))
    #expect(source.contains("isSelected && differentiateWithoutColor"))
    #expect(source.contains(".overlay(alignment: .leading)"))
    #expect(source.contains("[.isButton, .isSelected] : .isButton"))
  }

  @Test
  func sessionRowUsesReducedRegularTypography() throws {
    let rowSource = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarSessionRow.swift"
    )
    let typographySource = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarSessionTypography.swift"
    )

    #expect(typographySource.contains("static let titlePointSize: CGFloat = 8"))
    #expect(typographySource.contains("static let supportingPointSize: CGFloat = 6"))
    #expect(typographySource.contains("static let weight: Font.Weight = .regular"))
    #expect(rowSource.contains("@ScaledMetric(relativeTo: .callout)"))
    #expect(rowSource.contains("@ScaledMetric(relativeTo: .caption)"))
    #expect(!rowSource.contains("weight(.medium)"))
  }

  @Test
  func sessionModesUseSpecifiedAdaptivePalette() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SessionMode+SidebarStyle.swift"
    )

    let darkRGBValues = [
      "138.0 / 255.0,\n        green: 118.0 / 255.0,\n        blue: 168.0 / 255.0",
      "107.0 / 255.0,\n        green: 143.0 / 255.0,\n        blue: 107.0 / 255.0",
      "92.0 / 255.0,\n        green: 130.0 / 255.0,\n        blue: 168.0 / 255.0",
      "79.0 / 255.0,\n        green: 140.0 / 255.0,\n        blue: 132.0 / 255.0",
      "163.0 / 255.0,\n        green: 138.0 / 255.0,\n        blue: 85.0 / 255.0",
    ]
    let lightRGBValues = [
      "107.0 / 255.0,\n        green: 87.0 / 255.0,\n        blue: 136.0 / 255.0",
      "76.0 / 255.0,\n        green: 110.0 / 255.0,\n        blue: 76.0 / 255.0",
      "62.0 / 255.0,\n        green: 97.0 / 255.0,\n        blue: 131.0 / 255.0",
      "49.0 / 255.0,\n        green: 107.0 / 255.0,\n        blue: 99.0 / 255.0",
      "122.0 / 255.0,\n        green: 101.0 / 255.0,\n        blue: 53.0 / 255.0",
    ]

    for rgb in darkRGBValues + lightRGBValues {
      #expect(source.contains(rgb))
    }
    #expect(source.contains("sidebarDarkAccent.opacity(0.14)"))
  }

  @Test
  func scoreBadgesUseUniversalDrillsAmber() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Sidebar/SidebarSessionScoreBadge.swift"
    )

    #expect(source.contains("SessionMode.drill.sidebarAccent(for: colorScheme)"))
    #expect(source.contains("SessionMode.drill.sidebarDarkAccent.opacity(0.16)"))
    #expect(source.contains("@ScaledMetric(relativeTo: .caption)"))
    #expect(!source.contains("switch score"))
    #expect(!source.contains("weight(.semibold)"))
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
