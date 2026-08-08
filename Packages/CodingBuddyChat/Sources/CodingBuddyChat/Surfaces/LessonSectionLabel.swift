//
//  LessonSectionLabel.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// Small caps section heading shared by the lesson cards (OUTCOME, OPEN,
/// SCENARIO, …), so every turn reads with the same rhythm.
struct LessonSectionLabel: View {
  let title: String
  let systemImage: String

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Label(title.uppercased(), systemImage: systemImage)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .labelStyle(.titleAndIcon)
  }
}
