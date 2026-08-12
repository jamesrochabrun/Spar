import AgentHubVoice
import CodingBuddyKit
import SwiftUI

public struct CodingBuddyVoiceTranscriptStrip: View {
  @Bindable private var controller: CodingBuddyVoiceController
  let onClose: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  public init(
    controller: CodingBuddyVoiceController,
    onClose: @escaping () -> Void
  ) {
    self.controller = controller
    self.onClose = onClose
  }

  public var body: some View {
    HStack(alignment: .top, spacing: EaselDesignSystem.Spacing.large) {
      Label("Voice coach", systemImage: "waveform")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 92, alignment: .leading)

      Divider()

      VStack(alignment: .leading, spacing: EaselDesignSystem.Spacing.xSmall) {
        if let errorMessage = controller.errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(EaselDesignSystem.Palette.danger)
        } else if controller.conversationTranscripts.isEmpty {
          Text(controller.conversationStatus.title)
            .foregroundStyle(.secondary)
        } else {
          ForEach(controller.conversationTranscripts.suffix(2)) { entry in
            (Text("\(roleLabel(for: entry.role)): ").bold() + Text(entry.text))
              .foregroundStyle(entry.isPartial ? .secondary : .primary)
          }
        }
      }
      .font(.callout)
      .lineLimit(2)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)

      Button("Hide voice transcript", systemImage: "xmark", action: onClose)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, EaselDesignSystem.Spacing.xLarge)
    .padding(.vertical, EaselDesignSystem.Spacing.medium)
    .frame(minHeight: 48)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  private func roleLabel(for role: VoiceTranscriptRole) -> String {
    switch role {
    case .user:
      "You"
    case .assistant:
      AppBrand.name
    case .system:
      "Update"
    case .tool:
      "Context"
    }
  }
}
