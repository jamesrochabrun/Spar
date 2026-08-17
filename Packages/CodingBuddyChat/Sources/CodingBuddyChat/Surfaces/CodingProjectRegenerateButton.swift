import CodingBuddyKit
import SwiftUI

/// "Regenerate" control for a Coding Project: opens the note popover, then asks
/// the interviewer to review the candidate's diff and re-issue the task list.
/// Shared by the Requirements surface and the report, so both entry points
/// carry the same optional note and the same disabled rules.
public struct CodingProjectRegenerateButton: View {
  private let canRegenerate: Bool
  private let isRegenerating: Bool
  private let onRegenerate: (String) -> Void

  @State private var isFormPresented = false
  @State private var details = ""

  public init(
    canRegenerate: Bool,
    isRegenerating: Bool,
    onRegenerate: @escaping (String) -> Void
  ) {
    self.canRegenerate = canRegenerate
    self.isRegenerating = isRegenerating
    self.onRegenerate = onRegenerate
  }

  public var body: some View {
    Button {
      isFormPresented = true
    } label: {
      Label(isRegenerating ? "Regenerating…" : "Regenerate", systemImage: "arrow.triangle.2.circlepath")
        .font(.callout.weight(.medium))
    }
    .easelSecondaryButton()
    .controlSize(.small)
    .disabled(!canRegenerate)
    .help("Ask the interviewer to review your work and re-issue the task list with what's left plus new work")
    .popover(isPresented: $isFormPresented, arrowEdge: .bottom) {
      CodingProjectRegenerationForm(
        details: $details,
        onSubmit: submit,
        onCancel: { isFormPresented = false }
      )
    }
  }

  private func submit() {
    isFormPresented = false
    onRegenerate(details)
    details = ""
  }
}
