import SwiftUI

struct ChatComposerVoiceCoachControl: View {
  let configuration: ChatComposerVoiceCoachAction

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 4) {
      if configuration.state.isActive {
        Button(
          configuration.state.isMuted ? "Unmute Voice Coach" : "Mute Voice Coach",
          systemImage: configuration.state.isMuted ? "mic.slash.fill" : "mic.fill",
          action: configuration.muteAction
        )
        .labelStyle(.iconOnly)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(
          configuration.state.isMuted
            ? CodingBuddyChatRuntimeStyle.failed
            : CodingBuddyChatRuntimeStyle.secondaryText(for: colorScheme)
        )
        .frame(width: 26, height: 26)
        .background(
          CodingBuddyChatRuntimeStyle.composerControlBackground(for: colorScheme),
          in: Circle()
        )
        .overlay {
          Circle()
            .stroke(CodingBuddyChatRuntimeStyle.border(for: colorScheme), lineWidth: 1)
        }
        .buttonStyle(.plain)
        .help(configuration.state.isMuted ? "Unmute microphone" : "Mute microphone")
        .transition(controlTransition)

        Button(
          "End Voice Coach",
          systemImage: "stop.fill",
          action: configuration.endAction
        )
        .labelStyle(.iconOnly)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(CodingBuddyChatRuntimeStyle.failed)
        .frame(width: 26, height: 26)
        .background(CodingBuddyChatRuntimeStyle.failed.opacity(0.12), in: Circle())
        .overlay {
          Circle()
            .stroke(CodingBuddyChatRuntimeStyle.failed.opacity(0.45), lineWidth: 1)
        }
        .buttonStyle(.plain)
        .help("End voice coach")
        .transition(controlTransition)
      }

      Button(action: configuration.primaryAction) {
        Label {
          Text(configuration.title)
        } icon: {
          if configuration.state.isActive, !reduceMotion {
            Image(systemName: systemImage)
              .symbolEffect(.variableColor.iterative.reversing)
          } else {
            Image(systemName: systemImage)
          }
        }
      }
      .buttonStyle(.plain)
      .labelStyle(.iconOnly)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(orbForeground)
      .frame(width: 30, height: 30)
      .background {
        switch configuration.state {
        case .disabled, .unavailable:
          Circle()
            .fill(CodingBuddyChatRuntimeStyle.composerControlBackground(for: colorScheme))
        case .failed:
          Circle()
            .fill(CodingBuddyChatRuntimeStyle.failed)
        default:
          Circle()
            .fill(
              LinearGradient(
                colors: [
                  CodingBuddyChatRuntimeStyle.voiceMagicViolet,
                  CodingBuddyChatRuntimeStyle.voiceMagicBlue,
                  CodingBuddyChatRuntimeStyle.voiceMagicMint,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
        }
      }
      .overlay {
        Circle()
          .strokeBorder(.white.opacity(0.42), lineWidth: 1)

        if !configuration.state.isActive,
           configuration.isEnabled,
           !configuration.state.isFailure {
          Image(systemName: "sparkle")
            .font(.system(size: 6, weight: .bold))
            .foregroundStyle(.white)
            .offset(x: 8, y: -8)
            .accessibilityHidden(true)
        }
      }
      .contentShape(Circle())
      .scaleEffect(isHovering && configuration.isEnabled ? 1.07 : 1)
      .shadow(color: haloColor, radius: haloRadius)
      .disabled(!configuration.isEnabled)
      .help(primaryHelp)
      .accessibilityValue(configuration.title)
      .accessibilityInputLabels(["Voice Coach", configuration.title])
      .onHover(perform: updateHoverState)
    }
    .animation(
      reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84),
      value: configuration.state.isActive
    )
    .accessibilityElement(children: .contain)
  }

  private var controlTransition: AnyTransition {
    reduceMotion
      ? .opacity
      : .move(edge: .trailing).combined(with: .opacity)
  }

  private var orbForeground: Color {
    switch configuration.state {
    case .disabled, .unavailable:
      CodingBuddyChatRuntimeStyle.tertiaryText(for: colorScheme)
    default:
      .white
    }
  }

  private var haloColor: Color {
    guard configuration.isEnabled, !configuration.state.isFailure else {
      return .clear
    }
    return configuration.state.isActive
      ? CodingBuddyChatRuntimeStyle.voiceMagicBlue.opacity(0.5)
      : CodingBuddyChatRuntimeStyle.voiceMagicViolet.opacity(isHovering ? 0.42 : 0.2)
  }

  private var haloRadius: Double {
    if configuration.state.isActive {
      5
    } else if isHovering {
      4
    } else {
      2
    }
  }

  private var systemImage: String {
    switch configuration.state {
    case .disabled, .unavailable, .ready, .listening, .userSpeaking:
      "waveform"
    case .connecting, .thinking, .executingTool:
      "sparkles"
    case .muted:
      "mic.slash.fill"
    case .speaking:
      "speaker.wave.2.fill"
    case .failed:
      "exclamationmark"
    }
  }

  private var primaryHelp: String {
    if let detail = configuration.detail {
      return detail
    }
    if configuration.state.isActive {
      return configuration.isTranscriptPresented
        ? "Hide voice transcript"
        : "Show voice transcript"
    }
    return "Start a voice conversation about this session"
  }

  private func updateHoverState(_ isHovering: Bool) {
    withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
      self.isHovering = isHovering
    }
  }
}
