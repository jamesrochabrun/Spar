import AgentHubVoice
import ClaudeCodeCore

public extension CodingBuddyVoiceController {
  func chatComposerVoiceCoachAction(
    isTranscriptPresented: Bool,
    onTranscriptToggle: @escaping @MainActor () -> Void
  ) -> ChatComposerVoiceCoachAction {
    let status = conversationStatus
    return ChatComposerVoiceCoachAction(
      state: ChatComposerVoiceCoachAction.State(conversationStatus: status),
      title: status.title,
      detail: status.detail,
      isEnabled: canUseVoice,
      isTranscriptPresented: isTranscriptPresented,
      primaryAction: status.isActive
        ? onTranscriptToggle
        : requestConversationToggle,
      muteAction: toggleMicrophoneMute,
      endAction: toggleConversation
    )
  }

  var chatComposerDictationAction: ChatComposerDictationAction {
    ChatComposerDictationAction(
      state: ChatComposerDictationAction.State(
        dictationState: viewModel.dictationState
      ),
      isEnabled: canUseVoice,
      action: toggleDictation
    )
  }
}

extension ChatComposerVoiceCoachAction.State {
  init(conversationStatus: CodingBuddyVoiceConversationStatus) {
    switch conversationStatus {
    case .disabled:
      self = .disabled
    case .unavailable:
      self = .unavailable
    case .ready:
      self = .ready
    case .connecting:
      self = .connecting
    case .listening:
      self = .listening
    case .muted:
      self = .muted
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
}

extension ChatComposerDictationAction.State {
  init(dictationState: DictationState) {
    switch dictationState {
    case .idle:
      self = .idle
    case .recording:
      self = .recording
    case .transcribing:
      self = .transcribing
    case .failed(let message):
      self = .failed(message)
    }
  }
}
