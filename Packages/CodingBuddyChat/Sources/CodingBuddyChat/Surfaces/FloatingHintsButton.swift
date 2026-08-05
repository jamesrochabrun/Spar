//
//  FloatingHintsButton.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

/// Floating editor accessory that presents the complete hints experience in
/// an anchored macOS popover without taking space from the surface picker.
public struct FloatingHintsButton: View {
  private let question: Question?
  private let attempt: InterviewAttempt?
  private let mode: SessionMode
  private let hintsRemaining: Int?
  private let onRequestHint: () -> Void

  @State private var isPresented = false
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(
    question: Question?,
    attempt: InterviewAttempt?,
    mode: SessionMode,
    hintsRemaining: Int?,
    onRequestHint: @escaping () -> Void
  ) {
    self.question = question
    self.attempt = attempt
    self.mode = mode
    self.hintsRemaining = hintsRemaining
    self.onRequestHint = onRequestHint
  }

  public var body: some View {
    Button("Open hints", systemImage: isPresented ? "lightbulb.fill" : "lightbulb.min") {
      if reduceMotion {
        isPresented.toggle()
      } else {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
          isPresented.toggle()
        }
      }
    }
    .labelStyle(.iconOnly)
    .font(.system(size: 17, weight: .semibold))
    .foregroundStyle(EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme))
    .frame(width: 44, height: 44)
    .background(
      EaselDesignSystem.Palette.primaryAction(for: colorScheme),
      in: Circle()
    )
    .overlay {
      Circle()
        .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.28), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.18), radius: 14, y: 7)
    .buttonStyle(.plain)
    .contentTransition(.symbolEffect(.replace))
    .symbolEffect(.bounce, value: reduceMotion ? false : isPresented)
    .help(hintHelpText)
    .accessibilityValue(hintAccessibilityValue)
    .popover(
      isPresented: $isPresented,
      attachmentAnchor: .point(.top),
      arrowEdge: .bottom
    ) {
      HintsView(
        question: question,
        attempt: attempt,
        mode: mode,
        hintsRemaining: hintsRemaining,
        onRequestHint: onRequestHint
      )
      .frame(width: 420, height: 520)
    }
  }

  private var hintHelpText: String {
    guard let hintsRemaining else { return "Open hints" }
    return hintsRemaining == 0
      ? "Open hints — budget spent"
      : "Open hints — \(hintsRemaining) remaining"
  }

  private var hintAccessibilityValue: String {
    guard let hintsRemaining else { return "Hint count unavailable" }
    return "\(hintsRemaining) remaining"
  }
}
