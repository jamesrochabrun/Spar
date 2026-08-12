import AgentHubVoice
import AgentHubVoicePanel
import CodingBuddyKit

public enum CodingBuddyVoiceConversationStatus: Equatable, Sendable {
  case disabled
  case unavailable
  case ready
  case connecting
  case listening
  case muted
  case userSpeaking
  case thinking
  case speaking
  case executingTool(String)
  case failed(String)

  init(
    isEnabled: Bool,
    isSessionAvailable: Bool,
    mode: VoiceHUDMode,
    realtimeState: VoiceEngineState,
    isMicrophoneMuted: Bool,
    isMicrophoneGated: Bool,
    isMicrophoneStandbyMuted: Bool
  ) {
    guard isEnabled else {
      self = .disabled
      return
    }
    guard isSessionAvailable else {
      self = .unavailable
      return
    }
    guard mode == .converse else {
      self = .ready
      return
    }

    switch realtimeState {
    case .disconnected:
      self = .ready
    case .connecting:
      self = .connecting
    case .idle:
      self = isMicrophoneMuted || isMicrophoneGated || isMicrophoneStandbyMuted
        ? .muted
        : .listening
    case .userSpeaking:
      self = .userSpeaking
    case .thinking:
      self = .thinking
    case .speaking:
      self = .speaking
    case .executingTool(let name):
      self = .executingTool(name)
    case .failed(let message):
      self = .failed(message)
    }
  }

  public var isActive: Bool {
    switch self {
    case .connecting, .listening, .muted, .userSpeaking, .thinking,
         .speaking, .executingTool:
      true
    case .disabled, .unavailable, .ready, .failed:
      false
    }
  }

  public var title: String {
    switch self {
    case .disabled:
      "Voice Off"
    case .unavailable, .ready:
      "Voice Coach"
    case .connecting:
      "Connecting…"
    case .listening:
      "Listening"
    case .muted:
      "Muted"
    case .userSpeaking:
      "You're speaking"
    case .thinking:
      "Thinking…"
    case .speaking:
      "\(AppBrand.name) speaking"
    case .executingTool:
      "Checking context…"
    case .failed:
      "Voice Error"
    }
  }

  public var systemImage: String {
    switch self {
    case .disabled, .muted:
      "mic.slash"
    case .unavailable, .ready, .listening, .userSpeaking:
      "waveform"
    case .connecting, .thinking:
      "ellipsis"
    case .speaking:
      "speaker.wave.2"
    case .executingTool:
      "gearshape"
    case .failed:
      "exclamationmark.triangle"
    }
  }

  public var detail: String? {
    switch self {
    case .disabled:
      "Enable voice features in Settings."
    case .unavailable:
      "Start or open a session to use the voice coach."
    case .failed(let message):
      message
    case .executingTool(let name):
      "Using \(name)"
    default:
      nil
    }
  }
}
