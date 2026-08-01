//
//  SessionReportView.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

/// Report surface: overall score, verdict, per-dimension rubric bars with
/// comments, summary, and improvement notes.
public struct SessionReportView: View {
  private let evaluation: RubricEvaluation?
  private let notes: [ImprovementNote]
  private let attempt: InterviewAttempt?

  @Environment(\.colorScheme) private var colorScheme

  public init(evaluation: RubricEvaluation?, notes: [ImprovementNote], attempt: InterviewAttempt?) {
    self.evaluation = evaluation
    self.notes = notes
    self.attempt = attempt
  }

  public var body: some View {
    Group {
      if let evaluation {
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            scoreHeader(evaluation)
            dimensionBars(evaluation)
            summarySection(evaluation)
            if !notes.isEmpty {
              notesSection
            }
          }
          .padding(24)
        }
      } else {
        ContentUnavailableView {
          Label("No evaluation yet", systemImage: "chart.bar.doc.horizontal")
        } description: {
          Text(emptyStateMessage)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }

  private func scoreHeader(_ evaluation: RubricEvaluation) -> some View {
    HStack(alignment: .center, spacing: 20) {
      ZStack {
        Circle()
          .stroke(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), lineWidth: 8)

        Circle()
          .trim(from: 0, to: evaluation.overallScore / 100)
          .stroke(scoreColor(evaluation.overallScore), style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))

        Text("\(Int(evaluation.overallScore.rounded()))")
          .font(.system(size: 26, weight: .bold, design: .rounded))
          .monospacedDigit()
      }
      .frame(width: 88, height: 88)

      VStack(alignment: .leading, spacing: 6) {
        if let verdict = evaluation.verdict {
          Text(verdictDisplay(verdict))
            .font(EaselDesignSystem.Typography.interface(size: 18, weight: .semibold))
            .foregroundStyle(verdictColor(verdict))
        }

        Text("Graded \(evaluation.createdAt.formatted(date: .abbreviated, time: .shortened))")
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        if let attempt, let duration = attempt.plannedDurationSeconds {
          Text("\(attempt.mode.displayName) · \(duration / 60) min · \(attempt.hintsUsed)/\(attempt.hintBudget) hints")
            .font(.caption)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }
      }

      Spacer()
    }
  }

  private func dimensionBars(_ evaluation: RubricEvaluation) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("Rubric")

      ForEach(evaluation.dimensionScores, id: \.dimension) { score in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(dimensionDisplay(score.dimension))
              .font(.system(size: 13, weight: .medium))

            Spacer()

            Text("\(formattedScore(score.score))/\(formattedScore(score.maxScore))")
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }

          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))

              Capsule()
                .fill(scoreColor(score.maxScore > 0 ? score.score / score.maxScore * 100 : 0))
                .frame(width: proxy.size.width * barFraction(score))
            }
          }
          .frame(height: 6)

          if let comment = score.comment, !comment.isEmpty {
            Text(comment)
              .font(.caption)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  private func summarySection(_ evaluation: RubricEvaluation) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Summary")

      Text(markdown(evaluation.summaryMarkdown))
        .font(.system(size: 13))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var notesSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionTitle("Room for improvement")

      ForEach(notes) { note in
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "arrow.up.forward.circle")
            .font(.system(size: 12))
            .foregroundStyle(EaselDesignSystem.Palette.accent)
            .padding(.top, 2)

          VStack(alignment: .leading, spacing: 2) {
            if let topicId = note.topicId {
              Text(topicId)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            }
            Text(markdown(note.noteMarkdown))
              .font(.system(size: 13))
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          EaselDesignSystem.Palette.surface(for: colorScheme),
          in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        )
        .overlay {
          RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
      }
    }
  }

  // MARK: - Helpers

  private var emptyStateMessage: String {
    switch attempt?.status {
    case .awaitingEvaluation:
      return "Buddy is grading the session — the report appears here when it lands."
    case .inProgress:
      return "Finish the session (or hit End & Grade) to get your rubric report."
    default:
      return "Complete a graded session to see the rubric report here."
    }
  }

  private func sectionTitle(_ text: String) -> some View {
    Text(text)
      .font(EaselDesignSystem.Typography.interface(size: 14, weight: .semibold))
  }

  private func barFraction(_ score: DimensionScore) -> CGFloat {
    guard score.maxScore > 0 else { return 0 }
    return CGFloat(min(1, max(0, score.score / score.maxScore)))
  }

  private func formattedScore(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
      ? String(Int(value))
      : String(format: "%.1f", value)
  }

  private func dimensionDisplay(_ dimension: String) -> String {
    dimension
      .split(separator: "_")
      .map { $0.prefix(1).uppercased() + $0.dropFirst() }
      .joined(separator: " ")
  }

  private func verdictDisplay(_ verdict: String) -> String {
    verdict
      .split(separator: "_")
      .map { $0.prefix(1).uppercased() + $0.dropFirst() }
      .joined(separator: " ")
  }

  private func verdictColor(_ verdict: String) -> Color {
    switch verdict {
    case "strong_hire": return .green
    case "hire": return .green
    case "lean_hire": return .orange
    case "no_hire": return .red
    default: return .primary
    }
  }

  private func scoreColor(_ score: Double) -> Color {
    switch score {
    case ..<50: return .red
    case ..<75: return .orange
    default: return .green
    }
  }

  private func markdown(_ text: String) -> AttributedString {
    (try? AttributedString(
      markdown: text,
      options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(text)
  }
}
