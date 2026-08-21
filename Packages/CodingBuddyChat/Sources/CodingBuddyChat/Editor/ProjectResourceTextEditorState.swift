import Foundation

struct ProjectResourceTextEditorState {
  private(set) var savedText: String
  var editorText: String
  private(set) var displayMode: EditorDisplayMode
  private(set) var documentID = UUID()
  private(set) var hasUnsavedChanges = false

  /// - Parameters:
  ///   - text: the content the file has on disk, used as the saved baseline.
  ///   - draft: an unsaved buffer to restore instead of `text`, such as the
  ///     edits a candidate left behind when they switched to another file.
  init(text: String, draft: String? = nil) {
    savedText = text
    editorText = draft ?? text
    displayMode = .displayMode(for: editorText)
    hasUnsavedChanges = draft.map { $0 != text } ?? false
  }

  mutating func editorTextChanged(_ updatedText: String) {
    editorText = updatedText
    if !hasUnsavedChanges {
      hasUnsavedChanges = updatedText != savedText
    }
  }

  mutating func editorReachedIdle(with text: String) {
    hasUnsavedChanges = text != savedText
  }

  mutating func synchronizeExternalText(_ text: String) {
    guard text != editorText else {
      // A matching parent update acknowledges the editor's controlled value,
      // such as a successful save. Keep the same WebView and its scroll state.
      savedText = text
      hasUnsavedChanges = false
      return
    }

    reset(with: text)
  }

  mutating func reset(with text: String, draft: String? = nil) {
    editorText = draft ?? text
    savedText = text
    displayMode = .displayMode(for: editorText)
    documentID = UUID()
    hasUnsavedChanges = draft.map { $0 != text } ?? false
  }
}
