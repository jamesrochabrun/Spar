//
//  SessionModeCard.swift
//  CodingBuddyChat
//
//  One row of the new-session mode chooser. Selecting a mode is the decision
//  that shapes the whole session, so the row states what the mode gives you
//  and when it tells you how you did — the segmented picker it replaces
//  showed only a name.
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

struct SessionModeCard: View {
  let mode: SessionMode
  let isSelected: Bool
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: mode.systemImage)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(isSelected ? selectionColor : .secondary)
          .frame(width: 20, height: 18)

        VStack(alignment: .leading, spacing: isSelected ? 6 : 2) {
          Text(mode.displayName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? selectionColor : .primary)

          Text(mode.usageSubtitle)
            .font(.system(size: 11))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .fixedSize(horizontal: false, vertical: true)

          if isSelected {
            briefRows
          }
        }

        Spacer(minLength: 0)

        // Selection is never colour alone: the filled check reads without
        // colour vision, in high contrast, and in a screenshot.
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(selectionColor)
          .opacity(isSelected ? 1 : 0)
          .accessibilityHidden(true)
      }
      .padding(.leading, 14)
      .padding(.trailing, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(background)
      .overlay(alignment: .leading) {
        if isSelected {
          Capsule()
            .fill(selectionColor)
            .frame(width: 3)
            .padding(.vertical, 8)
            .padding(.leading, 4)
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
          .stroke(
            isSelected
              ? selectionColor
              : EaselDesignSystem.Palette.border(for: colorScheme),
            lineWidth: isSelected ? 2 : 1
          )
      }
      .contentShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    }
    .buttonStyle(.plain)
    .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isSelected)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityLabel(mode.displayName)
    .accessibilityValue(accessibilityValue)
  }

  /// `Palette.accent` is near-black (#2E2F2F), so tinting with it left the
  /// selected card indistinguishable in dark mode. `selectionAccent` is the
  /// palette's actual highlight — sky blue on dark, ink on light.
  private var selectionColor: Color {
    EaselDesignSystem.Palette.selectionAccent(for: colorScheme)
  }

  private var background: some View {
    RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
      .fill(
        isSelected
          ? AnyShapeStyle(selectionColor.opacity(colorScheme == .dark ? 0.16 : 0.10))
          : AnyShapeStyle(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
      )
  }

  private var briefRows: some View {
    VStack(alignment: .leading, spacing: 3) {
      briefRow("Format", mode.brief.format)
      briefRow("Feedback", mode.brief.feedback)
      briefRow("Best for", mode.brief.bestFor)
    }
    .padding(.top, 2)
  }

  private func briefRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(label)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .frame(width: 52, alignment: .leading)

      Text(value)
        .font(.system(size: 11))
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var accessibilityValue: String {
    let brief = mode.brief
    return "\(mode.usageSubtitle). Format: \(brief.format). Feedback: \(brief.feedback). "
      + "Best for: \(brief.bestFor)."
  }
}
