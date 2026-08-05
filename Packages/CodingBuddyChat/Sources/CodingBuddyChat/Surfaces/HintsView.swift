//
//  HintsView.swift
//  CodingBuddyChat
//
//  Reusable hints content for the floating editor popover and non-coding
//  hints surface: active question recap, deterministic hint budget action,
//  and per-mode strategy guidance. Reference notes are never shown.
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

public struct HintsView: View {
  private let question: Question?
  private let attempt: InterviewAttempt?
  private let mode: SessionMode?
  private let hintsRemaining: Int?
  private let onRequestHint: () -> Void

  @State private var isPromptExpanded = true
  @Environment(\.colorScheme) private var colorScheme

  public init(
    question: Question?,
    attempt: InterviewAttempt?,
    mode: SessionMode?,
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
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let question {
          questionRecap(question)
        }

        if supportsHintBudget {
          hintBudgetCard
        }

        strategyCard

        if question == nil {
          Text(emptyStateMessage)
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }
      }
      .padding(20)
      .frame(maxWidth: 640, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }

  // MARK: - Question recap

  private func questionRecap(_ question: Question) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text(question.title)
          .font(EaselDesignSystem.Typography.interface(size: 17, weight: .semibold))
          .textSelection(.enabled)

        Spacer()

        statusLabel
      }

      HStack(spacing: 6) {
        difficultyChip(question.difficulty)

        ForEach(question.topicIds, id: \.self) { topicId in
          chip(topicId)
        }

        if let languageHint = question.languageHint {
          chip(languageHint)
        }
      }

      DisclosureGroup(isExpanded: $isPromptExpanded) {
        Text(markdown(question.promptMarkdown))
          .font(.system(size: 13))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 6)
      } label: {
        Text("Problem statement")
          .font(.callout.weight(.medium))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      }
    }
    .padding(16)
    .background(card)
  }

  // MARK: - Hint budget

  private var supportsHintBudget: Bool {
    guard let mode else { return false }
    return mode == .mockInterview || mode == .drill || mode == .practice
  }

  private var canRequestHint: Bool {
    attempt?.status == .inProgress && (hintsRemaining ?? 0) > 0
  }

  private var hintBudgetCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Hints", systemImage: "lightbulb")
          .font(EaselDesignSystem.Typography.interface(size: 14, weight: .semibold))

        Spacer()

        if let attempt {
          Text("\(attempt.hintsUsed) used of \(attempt.hintBudget)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }
      }

      Text(
        "Hints escalate: first a gentle nudge, then the pattern's name, then a skeleton of the approach. The interviewer never volunteers them — ask, or use the button."
      )
      .font(.caption)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .fixedSize(horizontal: false, vertical: true)

      Button {
        onRequestHint()
      } label: {
        Label(hintButtonTitle, systemImage: "lightbulb.fill")
          .font(.system(size: 12, weight: .semibold))
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .disabled(!canRequestHint)
    }
    .padding(16)
    .background(card)
  }

  private var hintButtonTitle: String {
    guard let hintsRemaining else { return "Request Hint" }
    if hintsRemaining == 0 { return "Hint budget spent" }
    return "Request Hint (\(hintsRemaining) left)"
  }

  // MARK: - Strategy guidance

  private var strategySteps: [(String, String)] {
    switch mode {
    case .systemDesign:
      return [
        ("1. Clarify requirements", "Functional and non-functional: users, scale, latency, consistency. Never design against assumptions you haven't said out loud."),
        ("2. Estimate", "Back-of-envelope: QPS, storage, bandwidth. Round aggressively; the exercise is the reasoning."),
        ("3. High-level design", "Boxes and arrows on the whiteboard first — API, services, data stores. Get agreement before diving deep."),
        ("4. Deep dive", "Pick the hardest component and go deep: data model, caching, queues, failure modes."),
        ("5. Trade-offs", "Name what you gave up (consistency vs availability, SQL vs NoSQL) — that's what's being graded."),
      ]
    case .behavioral:
      return [
        ("Situation", "One or two sentences of context. Specific project, specific stakes."),
        ("Task", "What YOU were responsible for — not the team."),
        ("Action", "The concrete steps you took. This should be most of the answer."),
        ("Result", "Measurable impact, and what you'd do differently. Numbers beat adjectives."),
      ]
    default:
      return [
        ("1. Clarify", "Restate the problem, ask about edge cases, input ranges, and expected complexity before writing code."),
        ("2. Work an example", "Trace a small input by hand — it exposes the pattern and catches misunderstandings early."),
        ("3. Brute force first", "State the naive approach and its complexity out loud, then improve it."),
        ("4. Code it", "Write your solution in the Workspace tab and save (⌘S) — the interviewer grades those files."),
        ("5. Test & analyze", "Walk through your code with the example, cover edge cases, state time and space complexity."),
      ]
    }
  }

  private var strategyTitle: String {
    switch mode {
    case .systemDesign: return "How to run a design interview"
    case .behavioral: return "Answer with STAR"
    default: return "How to tackle it"
    }
  }

  private var strategyCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(strategyTitle, systemImage: "map")
        .font(EaselDesignSystem.Typography.interface(size: 14, weight: .semibold))

      ForEach(strategySteps, id: \.0) { step in
        VStack(alignment: .leading, spacing: 2) {
          Text(step.0)
            .font(.system(size: 13, weight: .medium))
          Text(step.1)
            .font(.caption)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(16)
    .background(card)
  }

  // MARK: - Helpers

  private var emptyStateMessage: String {
    if attempt == nil {
      return "Start a session from the sidebar to get a question."
    }
    return "Buddy presents the question in chat — it lands here automatically."
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

  private func chip(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(
        Capsule().fill(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
      )
      .overlay {
        Capsule().stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
  }

  private func markdown(_ text: String) -> AttributedString {
    (try? AttributedString(
      markdown: text,
      options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(text)
  }

  private var card: some View {
    RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
      .fill(EaselDesignSystem.Palette.surface(for: colorScheme))
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
  }
}
