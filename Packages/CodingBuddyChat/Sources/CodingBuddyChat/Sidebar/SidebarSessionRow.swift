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
    HStack(spacing: 4) {
      Button(action: onSelect) {
        HStack(spacing: 8) {
          ZStack {
            Circle()
              .stroke(
                isSelected
                  ? selectionAccent
                  : EaselDesignSystem.Palette.tertiaryText(for: colorScheme),
                lineWidth: 1
              )

            if isSelected {
              Circle()
                .fill(selectionAccent)
                .padding(2)
            }
          }
          .frame(width: 8, height: 8)
          .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              modeLabel

              Text(row.session.provider.displayName)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                .lineLimit(1)

              statusBadge

              Spacer()

              scoreChip

              Text(relativeTime)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            }

            Text(row.displayTitle)
              .font(
                .system(.caption, design: .monospaced)
                  .weight(isSelected ? .semibold : .regular)
              )
              .foregroundStyle(isSelected ? Color.primary : EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .lineLimit(1)
              .truncationMode(.tail)
          }
        }
        .padding(.leading, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity)
      .accessibilityLabel("Open \(row.mode.displayName) session: \(row.displayTitle)")
      .accessibilityAddTraits(isSelected ? .isSelected : [])

      Button(role: .destructive, action: onDelete) {
        Label("Delete \(row.displayTitle)", systemImage: "trash")
          .labelStyle(.iconOnly)
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
      .help("Delete session and project")
      .padding(.trailing, 8)
    }
    .background {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
        .fill(isSelected ? selectionSurface : Color.clear)
    }
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
        .stroke(
          isSelected ? selectionAccent.opacity(0.65) : Color.clear,
          lineWidth: 1
        )
    }
    .overlay(alignment: .leading) {
      if isSelected {
        RoundedRectangle(cornerRadius: 1.5)
          .fill(selectionAccent)
          .frame(width: 3)
          .padding(.vertical, 5)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control))
    .contextMenu {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }
  }

  private var selectionAccent: Color {
    EaselDesignSystem.Palette.selectionAccent(for: colorScheme)
  }

  private var selectionSurface: Color {
    selectionAccent.opacity(colorScheme == .dark ? 0.18 : 0.12)
  }

  private var modeLabel: some View {
    Label(row.mode.displayName, systemImage: row.mode.systemImage)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .lineLimit(1)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background {
        Capsule()
          .fill(EaselDesignSystem.Palette.secondaryText(for: colorScheme).opacity(0.12))
      }
      .layoutPriority(1)
      .accessibilityHidden(true)
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
