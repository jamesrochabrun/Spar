//
//  SidebarSessionRow.swift
//  CodingBuddyChat
//

import ClaudeCodeCore
import CodingBuddyKit
import InterviewKit
import SwiftUI

struct SidebarSessionRow: View {
  let row: AttemptRow
  let isSelected: Bool
  let onSelect: () -> Void
  let onDelete: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 8) {
        Circle()
          .fill(isSelected ? EaselDesignSystem.Palette.accent : EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          .frame(width: 6, height: 6)

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(row.session.provider.displayName)
              .font(.system(.caption2, design: .monospaced))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

            statusBadge

            Spacer()

            scoreChip

            Text(relativeTime)
              .font(.system(.caption2, design: .monospaced))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }

          Text(row.displayTitle)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(isSelected ? Color.primary : EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(isSelected ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    if let status = row.attempt?.status {
      switch status {
      case .inProgress:
        Image(systemName: "circle.dotted")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.orange)
          .help("In progress")
      case .awaitingEvaluation:
        Image(systemName: "hourglass")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.orange)
          .help("Awaiting evaluation")
      case .abandoned:
        Image(systemName: "xmark.circle")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          .help("Abandoned")
      case .evaluated:
        EmptyView()
      }
    }
  }

  @ViewBuilder
  private var scoreChip: some View {
    if let score = row.overallScore {
      Text("\(Int(score.rounded()))")
        .font(.system(.caption2, design: .monospaced).weight(.semibold))
        .foregroundStyle(scoreColor(score))
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(
          Capsule().fill(scoreColor(score).opacity(0.16))
        )
        .help("Overall score: \(Int(score.rounded()))/100")
    }
  }

  private func scoreColor(_ score: Double) -> Color {
    switch score {
    case ..<50: return .red
    case ..<75: return .orange
    default: return .green
    }
  }

  private var relativeTime: String {
    let interval = Date().timeIntervalSince(row.session.lastAccessedAt)
    if interval < 60 {
      return "now"
    } else if interval < 3600 {
      let minutes = Int(interval / 60)
      return "\(minutes)m ago"
    } else if interval < 86400 {
      let hours = Int(interval / 3600)
      return "\(hours)h ago"
    } else {
      let days = Int(interval / 86400)
      return "\(days)d ago"
    }
  }
}
