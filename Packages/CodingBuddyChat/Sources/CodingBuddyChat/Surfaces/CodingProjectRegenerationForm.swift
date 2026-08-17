import CodingBuddyKit
import SwiftUI

/// Popover behind the Requirements surface's Regenerate button: an optional
/// note the candidate can steer the next round with, before the interviewer
/// reviews their diff and re-issues the task list.
struct CodingProjectRegenerationForm: View {
  @Binding var details: String
  let onSubmit: () -> Void
  let onCancel: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var isDetailFieldFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Regenerate tasks")
          .font(.headline)

        Text("The interviewer reviews your Git diff, drops what you finished, keeps what you didn't, and adds new work.")
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Anything to steer it? (optional)")
            .font(.callout.weight(.medium))

          Spacer()

          Text("\(details.count)/\(CodingProjectBrief.maximumCharacterCount)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        }

        TextField(
          "Example: more performance bugs, a bit harder, and keep the navigation work I started.",
          text: $details,
          axis: .vertical
        )
        .lineLimit(3...6)
        .textFieldStyle(.roundedBorder)
        .focused($isDetailFieldFocused)
        .onChange(of: details) { _, value in
          let limited = CodingProjectBrief.limitedInput(value)
          if limited != value {
            details = limited
          }
        }
      }

      HStack(spacing: 8) {
        Spacer()

        Button("Cancel", role: .cancel, action: onCancel)
          .foregroundStyle(EaselDesignSystem.Palette.accentForeground(for: colorScheme))
          .keyboardShortcut(.cancelAction)

        Button("Send to Interviewer", action: onSubmit)
          .buttonStyle(.borderedProminent)
          .tint(EaselDesignSystem.Palette.accent)
          // Return belongs to the multi-line field, so the send lives on ⌘Return.
          .keyboardShortcut(.return, modifiers: .command)
      }
    }
    .padding(16)
    .frame(width: 380)
    .onAppear {
      isDetailFieldFocused = true
    }
  }
}
