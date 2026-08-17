//
//  LessonCompletionButton.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// Completion is the learner's call, never the agent's — the agent can only
/// suggest via `item_complete`. This button is the only thing that writes it.
struct LessonCompletionButton: View {
  let isCompleted: Bool
  let isEnabled: Bool
  let isProminent: Bool
  let onSetCompletion: (Bool) -> Void

  var body: some View {
    Button(action: toggle) {
      Label(
        isCompleted ? "Completed" : "Mark Item Complete",
        systemImage: isCompleted ? "checkmark.circle.fill" : "circle"
      )
      .font(.system(size: 12, weight: .medium))
    }
    .easelSecondaryButton()
    .controlSize(.small)
    .tint(isProminent && !isCompleted ? .accentColor : nil)
    .disabled(!isEnabled)
    .help(
      isCompleted
        ? "Marked complete — click to reopen this item"
        : "You decide when this item is done"
    )
  }

  private func toggle() {
    onSetCompletion(!isCompleted)
  }
}
