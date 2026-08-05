//
//  DashboardView.swift
//  CodingBuddyChat
//
//  Full-window dashboard: topic skill bars by category, per-attempt score
//  trend, open improvement-notes checklist, and recent attempts with retry.
//

import Charts
import CodingBuddyKit
import InterviewKit
import SwiftUI

public struct DashboardView: View {
  private let skillStats: SkillStatsService
  private let onRetryQuestion: (Question) -> Void
  private let onOpenSession: (String) -> Void
  private let questionProvider: (String) async -> Question?

  @Environment(\.colorScheme) private var colorScheme

  public init(
    skillStats: SkillStatsService,
    onRetryQuestion: @escaping (Question) -> Void,
    onOpenSession: @escaping (String) -> Void,
    questionProvider: @escaping (String) async -> Question?
  ) {
    self.skillStats = skillStats
    self.onRetryQuestion = onRetryQuestion
    self.onOpenSession = onOpenSession
    self.questionProvider = questionProvider
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        if hasAnyData {
          skillsSection
          trendSection
          if !skillStats.openNotes.isEmpty {
            notesSection
          }
          recentAttemptsSection
        } else {
          emptyState
        }
      }
      .padding(24)
      .frame(maxWidth: 900, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .task {
      await skillStats.refresh()
    }
  }

  private var hasAnyData: Bool {
    !skillStats.recentAttempts.isEmpty || !skillStats.openNotes.isEmpty
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No data yet", systemImage: "chart.bar.xaxis")
    } description: {
      Text("Complete a graded session and your skill stats will land here.")
    }
    .frame(maxWidth: .infinity, minHeight: 400)
  }

  // MARK: - Topic skill bars

  private static let categories: [(id: String, title: String)] = [
    ("algorithms", "Algorithms & Data Structures"),
    ("ios", "iOS Engineering"),
    ("system-design", "System Design"),
    ("behavioral", "Behavioral"),
  ]

  private var skillsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      sectionTitle("Skills by topic")

      ForEach(Self.categories, id: \.id) { category in
        let stats = skillStats.stats(forCategory: category.id)
          .filter { $0.averageScore != nil }
        if !stats.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text(category.title)
              .font(.callout.weight(.medium))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

            Chart(stats, id: \.topicId) { stat in
              BarMark(
                x: .value("Score", stat.averageScore ?? 0),
                y: .value("Topic", skillStats.topic(for: stat.topicId)?.displayName ?? stat.topicId)
              )
              .foregroundStyle(barColor(stat.averageScore ?? 0))
              .annotation(position: .trailing, spacing: 4) {
                Text("\(Int((stat.averageScore ?? 0).rounded())) · \(stat.attemptCount)×")
                  .font(.caption2.monospacedDigit())
                  .foregroundStyle(.secondary)
              }
            }
            .chartXScale(domain: 0...100)
            .frame(height: CGFloat(stats.count) * 34 + 20)
          }
        }
      }
    }
    .padding(20)
    .background(cardBackground)
  }

  // MARK: - Trend

  private struct TrendPoint: Identifiable {
    let id: String
    let date: Date
    let score: Double
    let mode: String
  }

  private var trendPoints: [TrendPoint] {
    skillStats.recentAttempts.compactMap { summary in
      guard let score = summary.overallScore else { return nil }
      return TrendPoint(
        id: summary.attempt.id,
        date: summary.attempt.startedAt,
        score: score,
        mode: summary.attempt.mode.displayName
      )
    }
    .sorted { $0.date < $1.date }
  }

  @ViewBuilder
  private var trendSection: some View {
    let points = trendPoints
    if points.count >= 2 {
      VStack(alignment: .leading, spacing: 12) {
        sectionTitle("Score trend")

        Chart(points) { point in
          LineMark(
            x: .value("Date", point.date),
            y: .value("Score", point.score)
          )
          .foregroundStyle(by: .value("Mode", point.mode))

          PointMark(
            x: .value("Date", point.date),
            y: .value("Score", point.score)
          )
          .foregroundStyle(by: .value("Mode", point.mode))
        }
        .chartYScale(domain: 0...100)
        .frame(height: 220)
      }
      .padding(20)
      .background(cardBackground)
    }
  }

  // MARK: - Improvement notes

  private var notesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("Room for improvement")

      ForEach(skillStats.openNotes) { note in
        HStack(alignment: .top, spacing: 10) {
          Button {
            Task { await skillStats.setNoteResolved(note, resolved: true) }
          } label: {
            Image(systemName: "circle")
              .font(.system(size: 14))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }
          .buttonStyle(.plain)
          .help("Mark resolved")

          VStack(alignment: .leading, spacing: 2) {
            if let topicId = note.topicId {
              Text(skillStats.topic(for: topicId)?.displayName ?? topicId)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            }
            Text(note.noteMarkdown)
              .font(.system(size: 13))
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()
        }
        .padding(.vertical, 4)
      }
    }
    .padding(20)
    .background(cardBackground)
  }

  // MARK: - Recent attempts

  private var recentAttemptsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("Recent attempts")

      VStack(spacing: 0) {
        ForEach(skillStats.recentAttempts.prefix(15)) { summary in
          attemptRow(summary)
          if summary.id != skillStats.recentAttempts.prefix(15).last?.id {
            Divider()
          }
        }
      }
    }
    .padding(20)
    .background(cardBackground)
  }

  private func attemptRow(_ summary: SkillStatsService.AttemptSummary) -> some View {
    HStack(spacing: 12) {
      Image(systemName: summary.attempt.mode.systemImage)
        .font(.system(size: 13))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 1) {
        Text(summary.questionTitle ?? summary.attempt.mode.displayName)
          .font(.system(size: 13, weight: .medium))
          .lineLimit(1)

        Text(summary.attempt.startedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if let score = summary.overallScore {
        Text("\(Int(score.rounded()))")
          .font(.system(.caption, design: .monospaced).weight(.semibold))
          .foregroundStyle(barColor(score))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Capsule().fill(barColor(score).opacity(0.15)))
      } else {
        Text(statusText(summary.attempt.status))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if let chatSessionId = summary.attempt.chatSessionId {
        Button("Open") {
          onOpenSession(chatSessionId)
        }
        .controlSize(.small)
      }

      if let questionId = summary.attempt.questionId {
        Button("Retry") {
          Task {
            if let question = await questionProvider(questionId) {
              onRetryQuestion(question)
            }
          }
        }
        .controlSize(.small)
      }
    }
    .padding(.vertical, 8)
  }

  // MARK: - Helpers

  private func statusText(_ status: InterviewAttempt.Status) -> String {
    switch status {
    case .inProgress: return "In progress"
    case .awaitingEvaluation: return "Grading…"
    case .evaluated: return "Evaluated"
    case .abandoned: return "Abandoned"
    }
  }

  private func sectionTitle(_ text: String) -> some View {
    Text(text)
      .font(EaselDesignSystem.Typography.interface(size: 16, weight: .semibold))
  }

  private func barColor(_ score: Double) -> Color {
    switch score {
    case ..<50: return .red
    case ..<75: return .orange
    default: return .green
    }
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
      .fill(EaselDesignSystem.Palette.surface(for: colorScheme))
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
  }
}
