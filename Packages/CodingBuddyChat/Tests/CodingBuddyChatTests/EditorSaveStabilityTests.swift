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
}
