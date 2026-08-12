public struct ChatComposerVoiceCoachAction {
  public enum State: Equatable, Sendable {
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

    public var isActive: Bool {
      switch self {
      case .connecting, .listening, .muted, .userSpeaking, .thinking,
           .speaking, .executingTool:
        true
      case .disabled, .unavailable, .ready, .failed:
        false
      }
    }

    public var isMuted: Bool {
      self == .muted
    }

    public var isFailure: Bool {
      if case .failed = self {
        true
      } else {
        false
      }
    }
  }

  public let state: State
  public let title: String
  public let detail: String?
  public let isEnabled: Bool
  public let isTranscriptPresented: Bool
  public let primaryAction: @MainActor () -> Void
  public let muteAction: @MainActor () -> Void
  public let endAction: @MainActor () -> Void

  public init(
    state: State,
    title: String,
    detail: String?,
    isEnabled: Bool,
    isTranscriptPresented: Bool,
    primaryAction: @escaping @MainActor () -> Void,
    muteAction: @escaping @MainActor () -> Void,
    endAction: @escaping @MainActor () -> Void
  ) {
    self.state = state
    self.title = title
    self.detail = detail
    self.isEnabled = isEnabled
    self.isTranscriptPresented = isTranscriptPresented
    self.primaryAction = primaryAction
    self.muteAction = muteAction
    self.endAction = endAction
  }
}
