//
//  LessonCardBackground.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// The card chrome every lesson section sits on, matching the hints and report
/// surfaces so the Lesson tab doesn't read as a different app.
struct LessonCardBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
      .fill(EaselDesignSystem.Palette.surface(for: colorScheme))
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
  }
}
