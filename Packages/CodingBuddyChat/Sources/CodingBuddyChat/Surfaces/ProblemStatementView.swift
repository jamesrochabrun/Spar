//
//  ProblemStatementView.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

/// Problem surface: active question's markdown with difficulty/topic chips and
/// attempt status. Reference notes are never shown here.
public struct ProblemStatementView: View {
  private let question: Question?
  private let attempt: InterviewAttempt?

  @Environment(\.colorScheme) private var colorScheme

  public init(question: Question?, attempt: InterviewAttempt?) {
    self.question = question
    self.attempt = attempt
  }

  public var body: some View {
    Group {
      if let question {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            header(question)

            Divider()

            Text(promptText(question))
              .font(.system(size: 14))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(24)
        }
      } else {
        ContentUnavailableView {
          Label("No question yet", systemImage: "doc.text")
        } description: {
          Text(emptyStateMessage)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }

  private func header(_ question: Question) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(question.title)
        .font(EaselDesignSystem.Typography.interface(size: 20, weight: .semibold))
        .textSelection(.enabled)

      HStack(spacing: 6) {
        difficultyChip(question.difficulty)

        ForEach(question.topicIds, id: \.self) { topicId in
          chip(topicId, tint: EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }

        if let languageHint = question.languageHint {
          chip(languageHint, tint: EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }

        Spacer()

        statusLabel
      }
    }
  }

  private func difficultyChip(_ difficulty: Difficulty) -> some View {
    let color: Color
    switch difficulty {
    case .easy: color = .green
    case .medium: color = .orange
    case .hard: color = .red
    }
    return Text(difficulty.displayName)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Capsule().fill(color.opacity(0.15)))
  }

  private func chip(_ text: String, tint: Color) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(tint)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(
        Capsule().fill(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
      )
      .overlay {
        Capsule().stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
  }

  @ViewBuilder
  private var statusLabel: some View {
    if let status = attempt?.status {
      switch status {
      case .inProgress:
        Label("In progress", systemImage: "circle.dotted")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.orange)
      case .awaitingEvaluation:
        Label("Grading…", systemImage: "hourglass")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.orange)
      case .evaluated:
        Label("Evaluated", systemImage: "checkmark.circle")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.green)
      case .abandoned:
        Label("Abandoned", systemImage: "xmark.circle")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func promptText(_ question: Question) -> AttributedString {
    (try? AttributedString(
      markdown: question.promptMarkdown,
      options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(question.promptMarkdown)
  }

  private var emptyStateMessage: String {
    if attempt == nil {
      return "Start a session from the sidebar to get a question."
    }
    return "Buddy will present the question in chat — it lands here automatically."
  }
}
