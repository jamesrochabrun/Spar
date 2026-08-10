//
//  DrillRunStripView.swift
//  CodingBuddyChat
//
//  Live scoreboard for a drill run: one chip per graded rep, the running
//  tally, and the difficulty the next rep will use. A drill is many problems
//  inside one attempt, so without this the session looks identical to a mock
//  interview until the final report lands.
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

public struct DrillRunStripView: View {
  private let run: DrillRun
  private let nextDifficulty: Difficulty

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(run: DrillRun, nextDifficulty: Difficulty) {
    self.run = run
    self.nextDifficulty = nextDifficulty
  }

  public var body: some View {
    HStack(spacing: 10) {
      Label("Run", systemImage: "bolt")
        .font(.system(size: 11, weight: .semibold))
        .labelStyle(.titleAndIcon)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      repChips

      Spacer(minLength: 8)

      if !run.isEmpty {
        Text(tally)
          .font(.system(size: 11, weight: .medium))
          .monospacedDigit()
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        if run.currentStreak >= 2 {
          Label("\(run.currentStreak) in a row", systemImage: "flame")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.orange)
            .transition(.opacity)
        }
      }

      nextDifficultyBadge
    }
    .padding(.horizontal, 16)
    .frame(height: 30)
    .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: run.repCount)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityDescription)
  }

  private var repChips: some View {
    HStack(spacing: 4) {
      ForEach(visibleReps) { rep in
        Image(systemName: rep.verdict.systemImage)
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 16, height: 16)
          .background(color(for: rep.verdict), in: Circle())
          .help(helpText(for: rep))
      }

      // The rep now in flight, so the strip always shows where you are.
      Circle()
        .strokeBorder(
          EaselDesignSystem.Palette.border(for: colorScheme),
          style: StrokeStyle(lineWidth: 1, dash: [2, 2])
        )
        .frame(width: 16, height: 16)
        .help("Rep \(run.nextIndex) in progress")
    }
  }

  private var nextDifficultyBadge: some View {
    Text(nextDifficulty.displayName)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(difficultyColor)
      .padding(.horizontal, 7)
      .frame(height: 18)
      .background(difficultyColor.opacity(0.14), in: Capsule())
      .help(difficultyHelp)
  }

  /// Older reps scroll off rather than squeezing the strip — the tally keeps
  /// the full record.
  private var visibleReps: [DrillRep] {
    Array(run.reps.suffix(12))
  }

  private var tally: String {
    "\(run.cleanCount)/\(run.repCount) clean"
  }

  private var difficultyHelp: String {
    run.isEmpty
      ? "Next rep: \(nextDifficulty.displayName)"
      : "Next rep steps to \(nextDifficulty.displayName) based on your last reps"
  }

  private var accessibilityDescription: String {
    guard !run.isEmpty else {
      return "Drill run starting. First rep at \(nextDifficulty.displayName) difficulty."
    }
    return "Drill run: rep \(run.nextIndex). \(run.cleanCount) of \(run.repCount) clean. "
      + "Current streak \(run.currentStreak). Next rep at \(nextDifficulty.displayName) difficulty."
  }

  private func helpText(for rep: DrillRep) -> String {
    var text = "Rep \(rep.index): \(rep.verdict.displayName)"
    if let title = rep.questionTitle {
      text += " — \(title)"
    }
    if let note = rep.note {
      text += "\n\(note)"
    }
    return text
  }

  private func color(for verdict: DrillVerdict) -> Color {
    switch verdict {
    case .correct: return .green
    case .partial: return .orange
    case .incorrect: return .red
    }
  }

  private var difficultyColor: Color {
    switch nextDifficulty {
    case .easy: return .green
    case .medium: return .orange
    case .hard: return .red
    }
  }
}
