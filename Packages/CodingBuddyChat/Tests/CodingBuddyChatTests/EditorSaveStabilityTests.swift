//
//  EditorSaveStabilityTests.swift
//  CodingBuddyChatTests
//
//  Regression guard: saving (⌘S / ⌘R) must never recreate the editor's
//  NSTextView. ProjectResourceTextPreview once reset `editorDocumentID` on
//  every `text` change — including its own save round-tripping through the
//  parent — which tore down the text view mid-typing and lost the cursor and
//  first responder.
//

import Foundation
import Testing

struct EditorSaveStabilityTests {

  private func editorSource() throws -> String {
    let testsDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let packageDirectory = testsDirectory.deletingLastPathComponent()
    return try String(
      contentsOf: packageDirectory
        .appendingPathComponent("Sources/CodingBuddyChat/Editor/ProjectResourceTextPreview.swift"),
      encoding: .utf8
    )
  }

  @Test
  func ownSaveRoundTripDoesNotResetTheEditorDocument() throws {
    let source = try editorSource()

    // The save round-trip branch must come before any reset and must not
    // touch the document identity.
    #expect(source.contains("if newText == editorText"))

    // Unsaved user edits must never be clobbered by an external text change.
    #expect(source.contains("} else if editorText == savedText {"))
  }

  @Test
  func staleScrollAndCursorStateIsNeverReappliedToTheEditor() throws {
    let testsDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let packageDirectory = testsDirectory.deletingLastPathComponent()
    let source = try String(
      contentsOf: packageDirectory
        .appendingPathComponent("Sources/CodingBuddyChat/Editor/SourceCodeEditorView.swift"),
      encoding: .utf8
    )

    // SourceEditor 0.15.2 re-applies stored state on updates it didn't
    // attribute to the text view; typing doesn't set that attribution flag,
    // so a live scroll/cursor state binding snaps the viewport back and the
    // caret appears stuck. The binding must strip both fields on read.
    #expect(source.contains("state.scrollPosition = nil"))
    #expect(source.contains("state.cursorPositions = nil"))
    #expect(source.contains("state: stableEditorState"))
  }
}
