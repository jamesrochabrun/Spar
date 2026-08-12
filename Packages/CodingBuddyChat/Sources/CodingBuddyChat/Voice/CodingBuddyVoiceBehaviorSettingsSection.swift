import SwiftUI

struct CodingBuddyVoiceBehaviorSettingsSection: View {
  @Binding var voiceEnabled: Bool
  @Binding var autoSubmitDictation: Bool
  @Binding var screenCaptureEnabled: Bool
  @Binding var allowBargeIn: Bool
  @Binding var showTranscript: Bool
  let registrationError: String?
  let onShowOnboarding: () -> Void

  var body: some View {
    Section("Voice behavior") {
      Toggle(
        "Enable global shortcut (\(GlobalHotKey.voiceHUDDefault.displayString))",
        isOn: $voiceEnabled
      )

      Toggle("Automatically submit dictation", isOn: $autoSubmitDictation)

      Toggle(isOn: $screenCaptureEnabled) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Use screenshots")
          Text("Let voice requests send a display or region to the active chat agent")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Toggle(isOn: $allowBargeIn) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Allow interrupting the assistant")
          Text("Keeps the mic live during replies. Leave this off on open speakers to prevent echo interruptions.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Toggle(isOn: $showTranscript) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Show transcript text")
          Text("Replace the voice visualizer with the live conversation transcript")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Button("Show voice tour…", action: onShowOnboarding)

      if let registrationError {
        Label(registrationError, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
      }
    }
  }
}
