import AgentHubVoice
import AgentHubVoicePanel
import CodingBuddyKit
import SwiftUI

public struct CodingBuddyVoiceOnboardingView: View {
  @AppStorage private var screenCaptureEnabled: Bool
  @AppStorage private var voiceName: String
  @AppStorage private var onboardingCompleted: Bool

  @State private var hasScreenPermission = false

  private let screenCapture: any VoiceScreenCapturing
  private let onStartVoiceCoach: (() -> Void)?
  private let onDismiss: () -> Void

  public init(
    screenCapture: any VoiceScreenCapturing = VoiceScreenCaptureService(),
    onStartVoiceCoach: (() -> Void)? = nil,
    onDismiss: @escaping () -> Void
  ) {
    self.screenCapture = screenCapture
    self.onStartVoiceCoach = onStartVoiceCoach
    self.onDismiss = onDismiss
    _screenCaptureEnabled = AppStorage(
      wrappedValue: true,
      CodingBuddyVoiceDefaults.screenCaptureEnabled
    )
    _voiceName = AppStorage(
      wrappedValue: "marin",
      CodingBuddyVoiceDefaults.voiceName
    )
    _onboardingCompleted = AppStorage(
      wrappedValue: false,
      CodingBuddyVoiceDefaults.onboardingCompleted
    )
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: EaselDesignSystem.Spacing.xLarge) {
      HStack {
        VStack(alignment: .leading, spacing: EaselDesignSystem.Spacing.xSmall) {
          Text("Your session voice coach")
            .font(.title.bold())
          Text("Talk through the active interview without leaving your workspace.")
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Close voice tour", systemImage: "xmark", action: dismiss)
          .labelStyle(.iconOnly)
          .buttonStyle(.plain)
      }

      VStack(alignment: .leading, spacing: EaselDesignSystem.Spacing.large) {
        Label(
          "Discuss the current problem, recent interview dialogue, and workspace",
          systemImage: "bubble.left.and.text.bubble.right"
        )
        Label(
          "Start the coach from the colorful voice orb beside the message composer",
          systemImage: "sparkles"
        )
        Label(
          "Use the separate microphone when you only want to dictate a message",
          systemImage: "text.cursor"
        )
      }
      .font(.body)

      Divider()

      Picker("Coach voice", selection: $voiceName) {
        ForEach(VoiceOption.all) { option in
          Text("\(option.title) — \(option.tagline)").tag(option.id)
        }
      }

      Toggle(isOn: $screenCaptureEnabled) {
        VStack(alignment: .leading, spacing: EaselDesignSystem.Spacing.xSmall) {
          Text("Allow screen context")
          Text("The coach can inspect a screenshot only when you explicitly ask about what is visible.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .onChange(of: screenCaptureEnabled) { _, isEnabled in
        if isEnabled, !hasScreenPermission {
          hasScreenPermission = screenCapture.requestPermission()
        }
      }

      if screenCaptureEnabled, !hasScreenPermission {
        Label(
          "Screen Recording permission can be granted later in System Settings.",
          systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Spacer()

      HStack {
        Spacer()
        Button("Not Now", action: dismiss)
        Button(
          onStartVoiceCoach == nil ? "Done" : "Start Voice Coach",
          action: completeAndStart
        )
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(width: 520)
    .frame(minHeight: 430)
    .task {
      hasScreenPermission = screenCapture.hasPermission()
    }
  }

  private func dismiss() {
    onboardingCompleted = true
    onDismiss()
  }

  private func completeAndStart() {
    onboardingCompleted = true
    onDismiss()
    onStartVoiceCoach?()
  }
}
