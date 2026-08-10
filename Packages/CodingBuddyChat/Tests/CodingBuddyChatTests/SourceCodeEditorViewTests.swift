import AppKit
import CodingBuddyKit
import PierreDiffsSwift
import SwiftUI
import Testing

@testable import CodingBuddyChat

private func hexString(of color: Color) -> String {
  let resolvedColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
  let red = Int(round(resolvedColor.redComponent * 255))
  let green = Int(round(resolvedColor.greenComponent * 255))
  let blue = Int(round(resolvedColor.blueComponent * 255))
  return String(format: "#%02X%02X%02X", red, green, blue)
}

@Suite("SourceCodeEditorView")
struct SourceCodeEditorViewTests {
  @Test
  func saveEchoKeepsTheExistingEditorDocument() {
    var state = ProjectResourceTextEditorState(text: "let value = 1\n")
    let documentID = state.documentID

    state.editorTextChanged("let value = 2\n")
    state.synchronizeExternalText("let value = 2\n")

    #expect(state.editorText == "let value = 2\n")
    #expect(state.savedText == "let value = 2\n")
    #expect(!state.hasUnsavedChanges)
    #expect(state.documentID == documentID)
  }

  @Test
  func externalContentReplacementCreatesANewEditorDocument() {
    var state = ProjectResourceTextEditorState(text: "let value = 1\n")
    let documentID = state.documentID

    state.editorTextChanged("unsaved local edit\n")
    state.synchronizeExternalText("replacement from disk\n")

    #expect(state.editorText == "replacement from disk\n")
    #expect(state.savedText == "replacement from disk\n")
    #expect(!state.hasUnsavedChanges)
    #expect(state.documentID != documentID)
  }

  @Test
  func displayModeHighlightsNormalFiles() {
    let content = Array(repeating: "let value = 1", count: 1_000).joined(separator: "\n")

    #expect(EditorDisplayMode.displayMode(for: content) == .highlighted)
  }

  @Test
  func displayModeUsesFastModeForLargeFiles() {
    let largeByteContent = String(repeating: "a", count: 300_001)
    let largeLineContent = Array(repeating: "line", count: 5_001).joined(separator: "\n")
    let longLineContent = String(repeating: "a", count: 2_001)

    #expect(EditorDisplayMode.displayMode(for: largeByteContent) == .plainText)
    #expect(EditorDisplayMode.displayMode(for: largeLineContent) == .plainText)
    #expect(EditorDisplayMode.displayMode(for: longLineContent) == .plainText)
  }

  @Test
  func textFileMetricsTrackLargestLine() {
    let metrics = TextFileMetrics.metrics(for: "abc\nabcdef\nz")

    #expect(metrics.byteCount == 12)
    #expect(metrics.lineCount == 3)
    #expect(metrics.maxLineByteCount == 6)
  }

  @Test
  func editorOptionsPreserveWorkspaceWrappingAndForcePreviewWrapping() {
    let highlighted = EaselPierreEditorOptions(
      displayMode: .highlighted,
      isEditable: true,
      isWrapLinesEnabled: true
    )
    let highlightedWithoutWrapping = EaselPierreEditorOptions(
      displayMode: .highlighted,
      isEditable: true,
      isWrapLinesEnabled: false
    )
    let plainText = EaselPierreEditorOptions(
      displayMode: .plainText,
      isEditable: true,
      isWrapLinesEnabled: true
    )
    let readOnly = EaselPierreEditorOptions(
      displayMode: .highlighted,
      isEditable: false,
      isWrapLinesEnabled: false
    )
    let readOnlyFastMode = EaselPierreEditorOptions(
      displayMode: .plainText,
      isEditable: false,
      isWrapLinesEnabled: false
    )

    #expect(highlighted.overflowMode.rawValue == "wrap")
    #expect(highlightedWithoutWrapping.overflowMode.rawValue == "scroll")
    #expect(plainText.overflowMode.rawValue == "scroll")
    #expect(readOnly.overflowMode.rawValue == "wrap")
    #expect(readOnlyFastMode.overflowMode.rawValue == "wrap")
    #expect(highlighted.renderOptions.tokenizeMaxLength == nil)
    #expect(highlighted.renderOptions.tokenizeMaxLineLength == nil)
    #expect(plainText.renderOptions.tokenizeMaxLength == 0)
    #expect(plainText.renderOptions.tokenizeMaxLineLength == 0)
  }

  @Test
  func editorOptionsConfigurePierreAsAFullDocumentEditor() {
    let options = EaselPierreEditorOptions(
      displayMode: .highlighted,
      isEditable: true,
      isWrapLinesEnabled: true
    )
    let readOnlyOptions = EaselPierreEditorOptions(
      displayMode: .highlighted,
      isEditable: false,
      isWrapLinesEnabled: true
    )

    #expect(options.isEditing)
    #expect(readOnlyOptions.isEditing == false)
    #expect(options.renderOptions.diffIndicators.rawValue == "none")
    #expect(options.renderOptions.lineDiffType.rawValue == "none")
    #expect(options.renderOptions.disableFileHeader)
    #expect(options.renderOptions.disableBackground)
    #expect(options.renderOptions.expandUnchanged)
    #expect(options.editorOptions.historyMaxEntries == 100)
    #expect(options.editorOptions.matchBrackets)
    #expect(options.editorOptions.autoSurround.rawValue == "default")
  }

  @Test
  func fastModeDisablesExpensiveEditorFeatures() {
    let options = EaselPierreEditorOptions(
      displayMode: .plainText,
      isEditable: true,
      isWrapLinesEnabled: true
    )

    #expect(options.editorOptions.matchBrackets == false)
    #expect(options.editorOptions.autoSurround.rawValue == "never")
  }

  @Test
  func textPreviewHeaderStyleResolvesColorsFromRequestedColorScheme() {
    let lightStyle = ProjectResourceTextPreviewStyle(colorScheme: .light)
    let darkStyle = ProjectResourceTextPreviewStyle(colorScheme: .dark)

    #expect(hexString(of: lightStyle.editorBackground) == EaselDesignSystem.Palette.surfaceLightHex)
    #expect(hexString(of: lightStyle.headerBackground) == EaselDesignSystem.Palette.surfaceElevatedLightHex)
    #expect(hexString(of: lightStyle.headerSecondaryText) == EaselDesignSystem.Palette.textSecondaryLightHex)
    #expect(hexString(of: lightStyle.headerBorder) == EaselDesignSystem.Palette.borderLightHex)
    #expect(hexString(of: darkStyle.editorBackground) == "#12171C")
    #expect(hexString(of: darkStyle.headerBackground) == "#171C21")
    #expect(hexString(of: darkStyle.headerSecondaryText) == EaselDesignSystem.Palette.textSecondaryDarkHex)
  }

  @Test
  func languageResolverDetectsPierreSupportedFiles() {
    let cases: [(fileName: String, expectedIdentifier: String)] = [
      ("App.swift", "swift"),
      ("Component.tsx", "tsx"),
      ("types.d.ts", "typescript"),
      ("package.json", "json"),
      ("README.md", "markdown"),
      ("Dockerfile", "dockerfile"),
      ("Makefile", "makefile"),
      ("site.yaml", "yaml"),
    ]

    for testCase in cases {
      #expect(
        SourceEditorLanguageResolver.languageIdentifier(
          forFileName: testCase.fileName,
          content: "",
          displayMode: .highlighted
        ) == testCase.expectedIdentifier
      )
    }
  }

  @Test
  func languageResolverUsesShebangForExtensionlessScripts() {
    #expect(
      SourceEditorLanguageResolver.languageIdentifier(
        forFileName: "script",
        content: "#!/usr/bin/env python3\nprint('hello')",
        displayMode: .highlighted
      ) == "python"
    )
  }

  @Test
  func languageResolverFallsBackToPlainTextForFastMode() {
    #expect(
      SourceEditorLanguageResolver.languageIdentifier(
        forFileName: "App.swift",
        content: "let value = 1",
        displayMode: .plainText
      ) == "PlainText"
    )
  }
}
