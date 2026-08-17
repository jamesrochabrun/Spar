//
//  EaselControlStyles.swift
//  CodingBuddyKit
//

import SwiftUI

extension View {
  /// Styling for a secondary control on an Easel surface: bordered chrome plus
  /// a label color that carries contrast in both schemes.
  ///
  /// The app tint is a charcoal (`#2E2F2F`) sitting almost on top of the dark
  /// canvas (`#0D0F0E`), so a bordered button that inherits the default label
  /// color renders as dim gray on dark gray and reads as invisible. Every
  /// secondary action goes through here rather than naming its own foreground.
  public func easelSecondaryButton() -> some View {
    modifier(EaselSecondaryButton())
  }
}

struct EaselSecondaryButton: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .buttonStyle(.bordered)
      .foregroundStyle(EaselDesignSystem.Palette.accentForeground(for: colorScheme))
  }
}
