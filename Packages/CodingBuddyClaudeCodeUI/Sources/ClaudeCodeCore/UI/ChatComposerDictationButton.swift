import SwiftUI

struct ChatComposerDictationButton: View {
  let configuration: ChatComposerDictationAction

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: configuration.action) {
      Label {
        Text(buttonTitle)
      } icon: {
        stateIcon
      }
    }
    .labelStyle(.iconOnly)
    .font(.system(size: 13, weight: .medium))
    .foregroundStyle(foregroundStyle)
    .tint(foregroundStyle)
    .frame(width: 30, height: 30)
    .background(backgroundStyle, in: Circle())
    .overlay {
      Circle()
        .stroke(borderStyle, lineWidth: 1)
    }
    .contentShape(Circle())
    .buttonStyle(.plain)
    .disabled(!configuration.isEnabled || configuration.state == .transcribing)
    .help(helpText)
    .accessibilityValue(accessibilityValue)
  }

  @ViewBuilder
  private var stateIcon: some View {
    switch configuration.state {
    case .idle:
      Image(systemName: "mic")
    case .recording:
      Image(systemName: "stop.fill")
    case .transcribing:
      ProgressView()
        .controlSize(.mini)
    case .failed:
      Image(systemName: "exclamationmark.triangle")
    }
  }

  private var buttonTitle: String {
    switch configuration.state {
    case .idle, .failed:
      "Start dictation"
    case .recording:
      "Stop and transcribe"
    case .transcribing:
      "Transcribing"
    }
  }

  private var foregroundStyle: Color {
    switch configuration.state {
    case .recording, .failed:
      CodingBuddyChatRuntimeStyle.failed
    case .transcribing:
      CodingBuddyChatRuntimeStyle.running
    case .idle:
      CodingBuddyChatRuntimeStyle.tertiaryText(for: colorScheme)
    }
  }

  private var backgroundStyle: Color {
    switch configuration.state {
    case .recording:
      CodingBuddyChatRuntimeStyle.failed.opacity(0.12)
    case .transcribing:
      CodingBuddyChatRuntimeStyle.running.opacity(0.12)
    case .idle, .failed:
      CodingBuddyChatRuntimeStyle.composerControlBackground(for: colorScheme)
    }
  }

  private var borderStyle: Color {
    switch configuration.state {
    case .recording, .failed:
      CodingBuddyChatRuntimeStyle.failed.opacity(0.5)
    case .transcribing:
      CodingBuddyChatRuntimeStyle.running.opacity(0.5)
    case .idle:
      CodingBuddyChatRuntimeStyle.border(for: colorScheme)
    }
  }

  private var helpText: String {
    guard configuration.isEnabled else {
      return "Start or open a session to use dictation"
    }
    if case .failed(let message) = configuration.state {
      return message
    }
    return buttonTitle
  }

  private var accessibilityValue: String {
    switch configuration.state {
    case .idle:
      "Ready"
    case .recording:
      "Recording"
    case .transcribing:
      "Transcribing"
    case .failed(let message):
      message
    }
  }
}
