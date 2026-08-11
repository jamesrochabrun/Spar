//
//  LessonResponseEditor.swift
//  CodingBuddyChat
//
//  The learner's half of a lesson turn: a scaffold-seeded answer box plus the
//  three moves they can make on a task — answer it, ask for it to be narrowed,
//  or call the item done.
//

import CodingBuddyKit
import KnowledgeKit
import SwiftUI

struct LessonResponseEditor: View {
  let lesson: Lesson
  let isItemCompleted: Bool
  let canToggleCompletion: Bool
  let isLoading: Bool
  let onSubmit: (String) -> Void
  let onRequestHelp: () -> Void
  let onSetCompletion: (Bool) -> Void

  /// Seeded from the task's scaffold. The parent gives this view an `id` per
  /// turn, so a new task arrives with a fresh editor instead of the previous
  /// answer — which is already in the transcript.
  @State private var draft: String
  @Environment(\.colorScheme) private var colorScheme

  init(
    lesson: Lesson,
    isItemCompleted: Bool,
    canToggleCompletion: Bool,
    isLoading: Bool,
    onSubmit: @escaping (String) -> Void,
    onRequestHelp: @escaping () -> Void,
    onSetCompletion: @escaping (Bool) -> Void
  ) {
    self.lesson = lesson
    self.isItemCompleted = isItemCompleted
    self.canToggleCompletion = canToggleCompletion
    self.isLoading = isLoading
    self.onSubmit = onSubmit
    self.onRequestHelp = onRequestHelp
    self.onSetCompletion = onSetCompletion
    _draft = State(initialValue: lesson.replyScaffold)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        LessonSectionLabel(title: "Your response", systemImage: "square.and.pencil")

        Spacer()

        if !lesson.replyScaffold.isEmpty, draft != lesson.replyScaffold {
          Button("Reset to scaffold", action: resetToScaffold)
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.tint)
        }
      }

      TextField("Your answer", text: $draft, axis: .vertical)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .lineLimit(5...)
        .padding(8)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
        )
        .overlay {
          RoundedRectangle(cornerRadius: 6)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
        .accessibilityLabel("Your response")

      Text("The scaffold is a guide, not a format — answer in your own words.")
        .font(.caption)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      HStack(spacing: 8) {
        Button("Send Response", systemImage: "paperplane.fill", action: submit)
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .disabled(!canSubmit)
          .keyboardShortcut(.return, modifiers: .command)

        Button("I'm Stuck", systemImage: "questionmark.circle", action: onRequestHelp)
          .buttonStyle(.bordered)
          .controlSize(.small)
          .disabled(isLoading)
          .help("\(AppBrand.name) narrows this task without giving you the answer")

        Spacer()

        LessonCompletionButton(
          isCompleted: isItemCompleted,
          isEnabled: canToggleCompletion,
          isProminent: false,
          onSetCompletion: onSetCompletion
        )
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LessonCardBackground())
  }

  private var canSubmit: Bool {
    guard !isLoading else { return false }
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    // A scaffold with its blanks still in it is not an answer.
    return !trimmed.isEmpty && trimmed != lesson.replyScaffold.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func submit() {
    guard canSubmit else { return }
    onSubmit(draft)
    draft = ""
  }

  private func resetToScaffold() {
    draft = lesson.replyScaffold
  }
}
