import XCTest
import SwiftUI
import AppKit
import CodingBuddyKit
@testable import ClaudeCodeCore

final class AppearanceSettingsTests: XCTestCase {

  func testCustomThemeColorsUseProvidedHexValues() {
    let colors = ThemeColors.themeColors(
      for: .custom,
      customPrimaryHex: "#112233",
      customSecondaryHex: "#445566",
      customTertiaryHex: "#778899"
    )

    XCTAssertEqual(hexString(for: colors.brandPrimary), "#112233")
    XCTAssertEqual(hexString(for: colors.brandSecondary), "#445566")
    XCTAssertEqual(hexString(for: colors.brandTertiary), "#778899")
  }

  func testRuntimeStyleSurfacesStayNeutralAcrossThemes() {
    let claude = ThemeColors.themeColors(for: .claude)
    let bat = ThemeColors.themeColors(for: .bat)

    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.appBackground(for: .light, themeColors: claude)),
      hexString(for: CodingBuddyChatRuntimeStyle.appBackground(for: .light, themeColors: bat))
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.cardBackground(for: .dark, themeColors: claude)),
      hexString(for: CodingBuddyChatRuntimeStyle.cardBackground(for: .dark, themeColors: bat))
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.userBubble(for: .dark, themeColors: claude)),
      hexString(for: CodingBuddyChatRuntimeStyle.userBubble(for: .dark, themeColors: bat))
    )
  }

  func testClearThemeUsesNeutralPalette() {
    let clear = ThemeColors.themeColors(for: .clear)

    XCTAssertEqual(hexString(for: clear.brandPrimary), "#1F2937")
    XCTAssertEqual(hexString(for: clear.brandSecondary), "#6B7280")
    XCTAssertEqual(hexString(for: clear.brandTertiary), "#D1D5DB")
  }

  func testCodexThemeUsesOpenAINeutralPalette() {
    let codex = ThemeColors.themeColors(for: .codex)

    XCTAssertEqual(hexString(for: codex.brandPrimary), EaselDesignSystem.Palette.inkHex)
    XCTAssertEqual(hexString(for: codex.brandSecondary), EaselDesignSystem.Palette.accentHex)
    XCTAssertEqual(hexString(for: codex.brandTertiary), EaselDesignSystem.Palette.borderLightHex)
  }

  func testRuntimeStyleUsesCodexSurfaces() {
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.appBackground(for: .light)),
      EaselDesignSystem.Palette.canvasLightHex
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.appBackground(for: .dark)),
      EaselDesignSystem.Palette.canvasDarkHex
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.userBubble(for: .light)),
      EaselDesignSystem.Palette.accentHex
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.userMessageBubble(for: .light)),
      EaselDesignSystem.Palette.surfaceElevatedLightHex
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.userMessageBubble(for: .dark)),
      EaselDesignSystem.Palette.borderDarkHex
    )
  }

  func testRuntimeStyleUsesReadableInputTint() {
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.inputTint(for: .light)),
      EaselDesignSystem.Palette.accentHex
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.inputTint(for: .dark)),
      EaselDesignSystem.Palette.selectionAccentDarkHex
    )
  }

  func testToolCardsUseGraphiteChromeAndCompletion() {
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.toolCardBorder(for: .dark)),
      CodingBuddyChatRuntimeStyle.toolCardBorderDarkHex
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.completed),
      EaselDesignSystem.Palette.accentHex
    )
    XCTAssertEqual(
      hexString(for: CodingBuddyChatRuntimeStyle.completedForeground(for: .dark)),
      EaselDesignSystem.Palette.accentForegroundDarkHex
    )
  }

  private func hexString(for color: Color) -> String {
    let resolvedColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
    return Color.hexString(from: resolvedColor)
  }
}
