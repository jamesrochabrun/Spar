//
//  LessonTaskCard.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// The single task for this turn: one repository scenario the agent chose, and
/// the 2-3 things to look at in the cited source.
struct LessonTaskCard: View {
  let scenarioMarkdown: String
  let inspectSteps: [String]

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !scenarioMarkdown.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          LessonSectionLabel(title: "Scenario", systemImage: "sparkles")

          Text(LessonMarkdown.inline(scenarioMarkdown))
            .font(.system(size: 13))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if !inspectSteps.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          LessonSectionLabel(title: "Inspect", systemImage: "list.number")

          ForEach(Array(inspectSteps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text("\(index + 1).")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                .frame(minWidth: 18, alignment: .trailing)
                .accessibilityHidden(true)

              Text(LessonMarkdown.inline(step))
                .font(.system(size: 13))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Step \(index + 1): \(step)")
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LessonCardBackground())
  }
}
