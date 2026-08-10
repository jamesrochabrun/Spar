//
//  TimerPillView.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

/// Countdown pill for the persistent right-panel top bar: amber at 20%
/// remaining, red at 5%; pause on any timed session; "End & grade".
public struct TimerPillView: View {
  private let timer: SessionTimer
  private let onEndAndGrade: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  public init(timer: SessionTimer, onEndAndGrade: @escaping () -> Void) {
    self.timer = timer
    self.onEndAndGrade = onEndAndGrade
  }

  public var body: some View {
    HStack(spacing: 8) {
      if let remaining = timer.remaining {
        HStack(spacing: 5) {
          Image(systemName: timer.isPaused ? "pause.circle" : "timer")
            .font(.system(size: 11, weight: .semibold))

          Text(SessionTimer.formatted(remaining))
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .monospacedDigit()
        }
        .foregroundStyle(urgencyColor)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(Capsule().fill(urgencyColor.opacity(0.14)))
        .overlay {
          Capsule().stroke(urgencyColor.opacity(0.35), lineWidth: 1)
        }
        .help(timer.isPaused ? "Timer paused" : "Time remaining")

        // Pause used to be gated to practice — the one mode that never has a
        // timer, so the control could never appear. It belongs wherever a
        // countdown is actually running.
        Button(timer.isPaused ? "Resume timer" : "Pause timer",
               systemImage: timer.isPaused ? "play.fill" : "pause.fill") {
          if timer.isPaused {
            timer.resume()
          } else {
            timer.pause()
          }
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .font(.system(size: 10, weight: .semibold))
        .frame(width: 22, height: 22)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help(timer.isPaused ? "Resume timer" : "Pause timer")
      }

      Button("End & Grade", systemImage: "checkmark.seal", action: onEndAndGrade)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .fixedSize()
        .help("End the session now and get graded")
    }
    .fixedSize(horizontal: true, vertical: false)
  }

  private var urgencyColor: Color {
    guard let fraction = timer.fractionRemaining else {
      return colorScheme == .dark ? .white : .primary
    }
    if fraction <= 0.05 { return .red }
    if fraction <= 0.20 { return .orange }
    return colorScheme == .dark ? .white : .primary
  }
}
