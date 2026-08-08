//
//  LessonWrapUpCard.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// Shown when a turn arrives with no new task. The agent can suggest the item
/// is done; only the learner marks it.
struct LessonWrapUpCard: View {
  let isItemComplete: Bool
  let isItemCompleted: Bool
  let canToggleCompletion: Bool
  let isLoading: Bool
  let onSetCompletion: (Bool) -> Void
  let onStartNextItem: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LessonSectionLabel(
        title: isItemComplete ? "Item complete" : "Nothing left to inspect",
        systemImage: isItemComplete ? "checkmark.seal" : "flag.checkered"
      )

      Text(message)
        .font(.system(size: 13))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 8) {
        LessonCompletionButton(
          isCompleted: isItemCompleted,
          isEnabled: canToggleCompletion,
          isProminent: true,
          onSetCompletion: onSetCompletion
        )

        Button("Next Item", systemImage: "arrow.right", action: onStartNextItem)
          .buttonStyle(.bordered)
          .controlSize(.small)
          .disabled(isLoading)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LessonCardBackground())
  }

  private var message: String {
    isItemComplete
      ? "Buddy thinks you've met this item's outcome. The checkmark is yours to give — mark it when you agree."
      : "Buddy ended this turn without a new task. Mark the item complete, or move on and come back to it."
  }
}
