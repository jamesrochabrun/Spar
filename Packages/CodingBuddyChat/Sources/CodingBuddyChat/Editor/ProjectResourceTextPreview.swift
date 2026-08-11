//
//  ProjectResourceTextPreview.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

struct ProjectResourceTextPreview: View {
  let fileName: String
  let text: String
  let isSaving: Bool
  let onSave: (String) -> Void
  let isRunning: Bool
  let onUnsavedChangesChange: (Bool) -> Void
  let onEditorTextChange: (String) -> Void
  /// When set, a Run button appears that saves and runs the current buffer.
  let onRun: ((String) -> Void)?
  /// When set, a Review button appears that saves the buffer and asks Spar
  /// for a coaching review (locate failures, never reveal the solution).
  let onReview: ((String) -> Void)?

  init(
    fileName: String,
    text: String,
    isSaving: Bool,
    onSave: @escaping (String) -> Void,
    isRunning: Bool = false,
    onUnsavedChangesChange: @escaping (Bool) -> Void = { _ in },
    onEditorTextChange: @escaping (String) -> Void = { _ in },
    onRun: ((String) -> Void)? = nil,
    onReview: ((String) -> Void)? = nil
  ) {
    self.fileName = fileName
    self.text = text
    self.isSaving = isSaving
    self.onSave = onSave
    self.isRunning = isRunning
    self.onUnsavedChangesChange = onUnsavedChangesChange
    self.onEditorTextChange = onEditorTextChange
    self.onRun = onRun
    self.onReview = onReview
    self._editorState = State(initialValue: ProjectResourceTextEditorState(text: text))
  }

  @State private var editorState: ProjectResourceTextEditorState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    codePreview
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(previewStyle.editorBackground)
    .onChange(of: fileName) { _, _ in
      editorState.reset(with: text)
      onUnsavedChangesChange(false)
      onEditorTextChange(text)
    }
    .onChange(of: text) { _, newText in
      editorState.synchronizeExternalText(newText)
      onUnsavedChangesChange(editorState.hasUnsavedChanges)
      onEditorTextChange(editorState.editorText)
    }
  }

  private var codePreview: some View {
    VStack(spacing: 0) {
      editorHeader

      SourceCodeEditorView(
        text: $editorState.editorText,
        fileName: fileName,
        documentID: editorState.documentID,
        displayMode: editorState.displayMode,
        isEditable: true,
        onTextChange: editorTextChanged,
        onIdleTextSnapshot: editorIdleSnapshot
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var editorHeader: some View {
    HStack(spacing: 8) {
      Text(languageDisplayName.uppercased())
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(previewStyle.headerSecondaryText)

      if let badgeLabel = editorState.displayMode.badgeLabel {
        Text(badgeLabel)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(previewStyle.headerSecondaryText)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(
            Capsule()
              .fill(previewStyle.badgeBackground)
          )
      }

      if editorState.hasUnsavedChanges {
        Text("Modified")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.orange)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(
            Capsule()
              .fill(Color.orange.opacity(0.16))
          )
      }

      Spacer(minLength: 8)

      if editorState.hasUnsavedChanges {
        Button("Save") {
          onSave(editorState.editorText)
        }
        .keyboardShortcut("s", modifiers: .command)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isSaving)
      }

      if let onRun {
        Button("Run", systemImage: "play.fill") {
          onRun(editorState.editorText)
        }
        .keyboardShortcut("r", modifiers: .command)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isRunning || isSaving)
        .help("Save and run this file (⌘R)")
      }

      if let onReview {
        Button("Review", systemImage: "graduationcap") {
          onReview(editorState.editorText)
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isSaving)
        .help("Save and ask \(AppBrand.name) to review — points at what fails and how to tackle it, never the answer (⇧⌘E)")
      }
    }
    .frame(height: 32)
    .padding(.horizontal, 14)
    .background(previewStyle.headerBackground)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(previewStyle.headerBorder)
        .frame(height: 1)
    }
  }

  private var languageDisplayName: String {
    SourceEditorLanguageResolver.languageIdentifier(
      forFileName: fileName,
      content: editorState.editorText,
      displayMode: editorState.displayMode
    )
  }

  private var previewStyle: ProjectResourceTextPreviewStyle {
    ProjectResourceTextPreviewStyle(colorScheme: colorScheme)
  }

  private func editorTextChanged(_ updatedText: String) {
    editorState.editorTextChanged(updatedText)
    onUnsavedChangesChange(editorState.hasUnsavedChanges)
    onEditorTextChange(editorState.editorText)
  }

  private func editorIdleSnapshot(_ idleText: String) {
    editorState.editorReachedIdle(with: idleText)
    onUnsavedChangesChange(editorState.hasUnsavedChanges)
    onEditorTextChange(editorState.editorText)
  }
}
