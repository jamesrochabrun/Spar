//
//  GradingReportProgressView.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

struct GradingReportProgressView: View {
  /// Nil while the attempt can no longer be pulled back out of grading.
  var onCancel: (() -> Void)?

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 18) {
      ZStack {
        Circle()
          .fill(EaselDesignSystem.Palette.selectedSurface(for: colorScheme))
          .frame(width: 72, height: 72)

        ProgressView()
          .controlSize(.large)
          .tint(EaselDesignSystem.Palette.accentForeground(for: colorScheme))
      }

      VStack(spacing: 6) {
        Text("Building your interview report")
          .font(.title3)
          .bold()

        Text("\(AppBrand.name) is grading your solution against the session rubric. The report will appear here automatically.")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack(spacing: 8) {
        statusChip("Correctness", systemImage: "checkmark.circle")
        statusChip("Complexity", systemImage: "function")
        statusChip("Communication", systemImage: "bubble.left.and.bubble.right")
      }

      if let onCancel {
        Button("Cancel grading", systemImage: "arrow.uturn.backward", action: onCancel)
          .easelSecondaryButton()
          .controlSize(.small)
          .help("Stop grading and go back to the session")
      }
    }
    .padding(30)
    .frame(maxWidth: 520)
    .background(
      EaselDesignSystem.Palette.surface(for: colorScheme),
      in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.preview)
    )
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.preview)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 18, y: 8)
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Building your interview report")
    .accessibilityValue("Grading in progress")
  }

  private func statusChip(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(.caption)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(
        EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
        in: Capsule()
      )
  }
}
