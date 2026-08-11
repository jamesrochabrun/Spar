//
//  SidebarSessionRow.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

struct SidebarSessionRow: View {
  let row: AttemptRow
  let isSelected: Bool
  let showsRecency: Bool
  let onSelect: () -> Void
  let onDelete: () -> Void

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
  @Environment(\.colorScheme) private var colorScheme
  @ScaledMetric(relativeTo: .callout) private var titlePointSize =
    SidebarSessionTypography.titlePointSize
  @ScaledMetric(relativeTo: .caption) private var supportingPointSize =
    SidebarSessionTypography.supportingPointSize

  var body: some View {
    HStack(spacing: 2) {
      Button(action: onSelect) {
        HStack(spacing: 10) {
          SidebarSessionModeIcon(mode: row.mode)

          VStack(alignment: .leading, spacing: 0) {
            Text(row.mode.displayName.uppercased())
              .font(
                .system(
                  size: supportingPointSize,
                  weight: SidebarSessionTypography.weight
                )
              )
              .tracking(0.7)
              .foregroundStyle(row.mode.sidebarAccent(for: colorScheme))
              .lineLimit(1)

            Text(row.displayTitle)
              .font(
                .system(
                  size: titlePointSize,
                  weight: SidebarSessionTypography.weight
                )
              )
              .foregroundStyle(.primary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          if let score = row.overallScore {
            SidebarSessionScoreBadge(score: score)
          }

          if showsRecency {
            Text(recencyText)
              .font(
                .system(
                  size: supportingPointSize,
                  weight: SidebarSessionTypography.weight
                )
              )
              .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
              .monospacedDigit()
              .fixedSize()
          }
        }
        .padding(.leading, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Open \(row.mode.displayName) session: \(row.displayTitle)")
      .accessibilityValue(accessibilityValue)
      .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

      Button("Delete \(row.displayTitle)", systemImage: "trash", action: onDelete)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
        .help("Delete session and project")
        .padding(.trailing, 6)
    }
    .frame(minHeight: 50)
    .background(selectionSurface, in: RoundedRectangle(cornerRadius: 10))
    .overlay(alignment: .leading) {
      if isSelected && differentiateWithoutColor {
        Capsule()
          .fill(EaselDesignSystem.Palette.selectionAccent(for: colorScheme))
          .frame(width: 3)
          .padding(.vertical, 8)
          .padding(.leading, 3)
      }
    }
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .contextMenu {
      Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
    }
  }

  private var selectionSurface: Color {
    isSelected
      ? EaselDesignSystem.Palette.running.opacity(colorScheme == .dark ? 0.14 : 0.10)
      : .clear
  }

  private var recencyText: String {
    let interval = max(0, Date().timeIntervalSince(row.session.lastAccessedAt))
    switch interval {
    case ..<60:
      return "now"
    case ..<3_600:
      return "\(Int(interval / 60))m"
    case ..<86_400:
      return "\(Int(interval / 3_600))h"
    default:
      return "\(Int(interval / 86_400))d"
    }
  }

  private var accessibilityValue: String {
    var details: [String] = []
    if isSelected {
      details.append("Selected")
    }
    if let score = row.overallScore {
      details.append("Score \(Int(score.rounded())) out of 100")
    }
    if showsRecency {
      details.append(
        recencyText == "now"
          ? "Last opened just now"
          : "Last opened \(recencyText) ago"
      )
    } else {
      details.append("Last opened yesterday")
    }
    return details.joined(separator: ", ")
  }
}
