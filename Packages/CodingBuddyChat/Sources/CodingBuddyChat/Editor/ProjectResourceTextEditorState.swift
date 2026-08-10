import Foundation

struct ProjectResourceTextEditorState {
  private(set) var savedText: String
  var editorText: String
  private(set) var displayMode: EditorDisplayMode
  private(set) var documentID = UUID()
  private(set) var hasUnsavedChanges = false

  init(text: String) {
    savedText = text
    editorText = text
    displayMode = .displayMode(for: text)
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

  mutating func reset(with text: String) {
    editorText = text
    savedText = text
    displayMode = .displayMode(for: text)
    documentID = UUID()
    hasUnsavedChanges = false
  }
}
