//
//  LessonOutcomeCard.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// What this item is for. "Why this matters" is collapsible and starts open on
/// the opening turn only — by step three the learner has read it.
struct LessonOutcomeCard: View {
  let outcome: String
  let whyMarkdown: String
  let startsExpanded: Bool

  @State private var isWhyExpanded: Bool
  @Environment(\.colorScheme) private var colorScheme

  init(outcome: String, whyMarkdown: String, startsExpanded: Bool) {
    self.outcome = outcome
    self.whyMarkdown = whyMarkdown
    self.startsExpanded = startsExpanded
    _isWhyExpanded = State(initialValue: startsExpanded)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LessonSectionLabel(title: "Outcome", systemImage: "target")

      Text(outcome)
        .font(.system(size: 14, weight: .medium))
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)

      if !whyMarkdown.isEmpty {
        DisclosureGroup(isExpanded: $isWhyExpanded) {
          Text(LessonMarkdown.inline(whyMarkdown))
            .font(.system(size: 13))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        } label: {
          Text("Why this matters")
            .font(.callout.weight(.medium))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LessonCardBackground())
  }
}
