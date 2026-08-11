//
//  LessonHeaderView.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import KnowledgeKit
import SwiftUI

/// Where the learner is: which plan item, which step inside it, and a way out
/// to pick a different item — the plan is a menu, not a track.
struct LessonHeaderView: View {
  let lesson: Lesson
  let title: String
  let itemNumber: Int?
  let totalItemCount: Int?
  let isLoading: Bool
  let onOpenLibrary: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Text(itemPositionLabel)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        stepIndicator

        Spacer()

        if isLoading {
          HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("\(AppBrand.name) is responding…")
              .font(.caption)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }
        }

        Button("Learning Library", systemImage: "books.vertical", action: onOpenLibrary)
          .buttonStyle(.plain)
          .labelStyle(.iconOnly)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .help("Open Learning Library to pick another item")
      }

      Text(title)
        .font(EaselDesignSystem.Typography.interface(size: 17, weight: .semibold))
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  private var stepIndicator: some View {
    HStack(spacing: 5) {
      Text("Step \(lesson.step) of \(lesson.totalSteps)")
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      HStack(spacing: 3) {
        ForEach(1...max(1, lesson.totalSteps), id: \.self) { step in
          Circle()
            .fill(
              step <= lesson.step
                ? EaselDesignSystem.Palette.accent
                : EaselDesignSystem.Palette.border(for: colorScheme)
            )
            .frame(width: 6, height: 6)
        }
      }
      .accessibilityHidden(true)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Step \(lesson.step) of \(lesson.totalSteps)")
  }

  private var itemPositionLabel: String {
    guard let itemNumber, let totalItemCount else { return "LESSON" }
    return "ITEM \(itemNumber) OF \(totalItemCount)"
  }
}
