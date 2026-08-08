//
//  LessonSourceCard.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import KnowledgeKit
import SwiftUI

/// The one place the learner is told to look. Tapping it reveals the passage
/// on the Sources tab, which is what makes the task inspectable rather than
/// a recall prompt.
struct LessonSourceCard: View {
  let source: Lesson.SourceReference
  let onOpen: (Lesson.SourceReference) -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LessonSectionLabel(title: "Open", systemImage: "doc.text.magnifyingglass")

      Button(action: open) {
        HStack(spacing: 8) {
          Image(systemName: "doc.text")
            .foregroundStyle(.tint)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 2) {
            Text(source.displayName)
              .font(.system(size: 13, weight: .medium))
              .lineLimit(1)
              .truncationMode(.middle)

            Text(source.path)
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .lineLimit(1)
              .truncationMode(.head)
          }

          Spacer()

          Image(systemName: "arrow.up.forward.square")
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .accessibilityHidden(true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
        )
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Open \(source.displayName) in Sources")
      .help("Show this passage on the Sources tab")
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LessonCardBackground())
  }

  private func open() {
    onOpen(source)
  }
}
