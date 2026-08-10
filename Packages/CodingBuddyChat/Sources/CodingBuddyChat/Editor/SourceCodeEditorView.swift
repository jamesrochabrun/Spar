//
//  SourceCodeEditorView.swift
//  CodingBuddyChat
//

import Foundation
import PierreDiffsSwift
import SwiftUI

enum EditorDisplayMode: Equatable {
  case highlighted
  case plainText

  private static let highlightedByteLimit = 300_000
  private static let highlightedLineLimit = 5_000
  private static let highlightedMaxLineByteLimit = 2_000

  var badgeLabel: String? {
    switch self {
    case .highlighted:
      nil
    case .plainText:
      "Fast Mode"
    }
  }

  var highlightsSyntax: Bool {
    self == .highlighted
  }

  var usesFullEditorFeatures: Bool {
    self == .highlighted
  }

  static func displayMode(for content: String) -> EditorDisplayMode {
    displayMode(for: TextFileMetrics.metrics(for: content))
  }

  static func displayMode(for metrics: TextFileMetrics) -> EditorDisplayMode {
    if metrics.byteCount <= highlightedByteLimit,
       metrics.lineCount <= highlightedLineLimit,
       metrics.maxLineByteCount <= highlightedMaxLineByteLimit {
      return .highlighted
    }
    return .plainText
  }
}

struct SourceCodeEditorView: View {
  @Binding var text: String
  let fileName: String
  let documentID: UUID
  let displayMode: EditorDisplayMode
  var isEditable = true
  let onTextChange: (String) -> Void
  let onIdleTextSnapshot: (String) -> Void

  var body: some View {
    SourceCodeEditorHost(
      text: $text,
      fileName: fileName,
      displayMode: displayMode,
      isEditable: isEditable,
      onTextChange: onTextChange,
      onIdleTextSnapshot: onIdleTextSnapshot
    )
    .clipped()
    .id(documentID)
  }
}

private struct SourceCodeEditorHost: View {
  @Binding var text: String
  let fileName: String
  let displayMode: EditorDisplayMode
  let isEditable: Bool
  let onTextChange: (String) -> Void
  let onIdleTextSnapshot: (String) -> Void

  @AppStorage(EaselSourceEditorDefaults.wrapLinesEnabled)
  private var sourceEditorWrapLinesEnabled = true
  @State private var idleSnapshotTask: Task<Void, Never>?
  @State private var shouldUseFallbackEditor = false

  var body: some View {
    Group {
      if shouldUseFallbackEditor, isEditable {
        fallbackEditor
      } else {
        pierreEditor
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onDisappear {
      idleSnapshotTask?.cancel()
    }
  }

  private var pierreEditor: some View {
    PierreDiffView(
      oldContent: "",
      newContent: text,
      fileName: fileName,
      diffStyle: .constant(.unified),
      overflowMode: .constant(editorOptions.overflowMode),
      renderOptions: editorOptions.renderOptions,
      isEditing: editorOptions.isEditing,
      editorOptions: editorOptions.editorOptions,
      onEditChange: { change in
        guard change.content != text else { return }
        text = change.content
        reportTextChange(change.content)
      },
      onEditError: { _ in
        shouldUseFallbackEditor = true
      }
    )
  }

  private var fallbackEditor: some View {
    TextEditor(text: $text)
      .font(.system(size: 12, design: .monospaced))
      .textEditorStyle(.plain)
      .padding(8)
      .onChange(of: text) { _, newText in
        reportTextChange(newText)
      }
  }

  private var editorOptions: EaselPierreEditorOptions {
    EaselPierreEditorOptions(
      displayMode: displayMode,
      isEditable: isEditable,
      isWrapLinesEnabled: sourceEditorWrapLinesEnabled
    )
  }

  private func reportTextChange(_ updatedText: String) {
    onTextChange(updatedText)
    idleSnapshotTask?.cancel()
    idleSnapshotTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(650))
      guard !Task.isCancelled else { return }
      onIdleTextSnapshot(updatedText)
    }
  }
}

private enum EaselSourceEditorDefaults {
  static let keyPrefix = "com.easel."
  static let wrapLinesEnabled = "\(keyPrefix)editor.wrapLinesEnabled"
}

struct EaselPierreEditorOptions {
  let displayMode: EditorDisplayMode
  let isEditable: Bool
  let isWrapLinesEnabled: Bool

  var isEditing: Bool {
    isEditable
  }

  var overflowMode: OverflowMode {
    guard isEditable else { return .wrap }
    return isWrapLinesEnabled && displayMode.usesFullEditorFeatures ? .wrap : .scroll
  }

  var renderOptions: PierreDiffRenderOptions {
    PierreDiffRenderOptions(
      theme: .pierreSoft,
      diffIndicators: .none,
      hunkSeparators: .simple,
      lineDiffType: .none,
      disableLineNumbers: false,
      disableFileHeader: true,
      disableBackground: true,
      expandUnchanged: true,
      tokenizeMaxLength: displayMode.highlightsSyntax ? nil : 0,
      tokenizeMaxLineLength: displayMode.highlightsSyntax ? nil : 0
    )
  }

  var editorOptions: PierreDiffEditorOptions {
    PierreDiffEditorOptions(
      historyMaxEntries: 100,
      roundedSelection: true,
      matchBrackets: displayMode.usesFullEditorFeatures,
      autoSurround: displayMode.usesFullEditorFeatures ? .default : .never
    )
  }
}

enum SourceEditorLanguageResolver {
  static func languageIdentifier(
    forFileName fileName: String,
    content: String,
    displayMode: EditorDisplayMode
  ) -> String {
    guard displayMode.highlightsSyntax, !fileName.isEmpty else {
      return "PlainText"
    }

    let lowercasedFileName = fileName.lowercased()
    if lowercasedFileName == "dockerfile" || lowercasedFileName.hasSuffix("/dockerfile") {
      return "dockerfile"
    }
    if lowercasedFileName == "makefile" || lowercasedFileName.hasSuffix("/makefile") {
      return "makefile"
    }
    if lowercasedFileName.hasSuffix(".d.ts") {
      return "typescript"
    }

    let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
    if let language = languagesByFileExtension[fileExtension] {
      return language
    }

    return languageFromShebang(content) ?? "PlainText"
  }

  private static let languagesByFileExtension: [String: String] = [
    "bash": "bash",
    "c": "c",
    "cc": "cpp",
    "cjs": "javascript",
    "cpp": "cpp",
    "css": "css",
    "cxx": "cpp",
    "erb": "erb",
    "fish": "fish",
    "go": "go",
    "gql": "graphql",
    "graphql": "graphql",
    "h": "c",
    "hpp": "cpp",
    "htm": "html",
    "html": "html",
    "hxx": "cpp",
    "java": "java",
    "js": "javascript",
    "json": "json",
    "jsx": "jsx",
    "kt": "kotlin",
    "kts": "kotlin",
    "less": "less",
    "lua": "lua",
    "m": "objective-c",
    "md": "markdown",
    "mdx": "mdx",
    "mjs": "javascript",
    "mm": "objective-c",
    "php": "php",
    "plist": "xml",
    "ps1": "powershell",
    "psm1": "powershell",
    "py": "python",
    "pyi": "python",
    "pyw": "python",
    "r": "r",
    "rb": "ruby",
    "rs": "rust",
    "rst": "rst",
    "sass": "sass",
    "scala": "scala",
    "scss": "scss",
    "sh": "bash",
    "sql": "sql",
    "swift": "swift",
    "toml": "toml",
    "ts": "typescript",
    "tsx": "tsx",
    "xml": "xml",
    "yaml": "yaml",
    "yml": "yaml",
    "zig": "zig",
    "zsh": "bash",
  ]

  private static func languageFromShebang(_ content: String) -> String? {
    guard let firstLine = content.split(separator: "\n", maxSplits: 1).first,
          firstLine.hasPrefix("#!") else {
      return nil
    }

    let shebang = firstLine.lowercased()
    if shebang.contains("python") { return "python" }
    if shebang.contains("node") { return "javascript" }
    if shebang.contains("ruby") { return "ruby" }
    if shebang.contains("zsh") || shebang.contains("bash") || shebang.contains("/sh") {
      return "bash"
    }
    return nil
  }
}
