import AgentHubVoice
import ClaudeCodeCore
import Testing
@testable import CodingBuddyChat

struct CodingBuddyVoiceComposerActionTests {
  @Test
  func mapsEveryDictationStateIntoTheSharedComposerContract() {
    #expect(
      ChatComposerDictationAction.State(dictationState: .idle) == .idle
    )
    #expect(
      ChatComposerDictationAction.State(dictationState: .recording)
        == .recording
    )
    #expect(
      ChatComposerDictationAction.State(dictationState: .transcribing)
        == .transcribing
    )
    #expect(
      ChatComposerDictationAction.State(dictationState: .failed("No microphone"))
        == .failed("No microphone")
    )
  }

  @Test
  func mapsEveryConversationStateIntoTheSharedComposerContract() {
    #expect(makeState(.disabled) == .disabled)
    #expect(makeState(.unavailable) == .unavailable)
    #expect(makeState(.ready) == .ready)
    #expect(makeState(.connecting) == .connecting)
    #expect(makeState(.listening) == .listening)
    #expect(makeState(.muted) == .muted)
    #expect(makeState(.userSpeaking) == .userSpeaking)
    #expect(makeState(.thinking) == .thinking)
    #expect(makeState(.speaking) == .speaking)
    #expect(makeState(.executingTool("read_file")) == .executingTool("read_file"))
    #expect(makeState(.failed("No microphone")) == .failed("No microphone"))
  }

  @Test
  func sharedConversationStatesExposeComposerControlBehavior() {
    #expect(ChatComposerVoiceCoachAction.State.connecting.isActive)
    #expect(ChatComposerVoiceCoachAction.State.listening.isActive)
    #expect(ChatComposerVoiceCoachAction.State.muted.isActive)
    #expect(ChatComposerVoiceCoachAction.State.muted.isMuted)
    #expect(!ChatComposerVoiceCoachAction.State.ready.isActive)
    #expect(ChatComposerVoiceCoachAction.State.failed("Offline").isFailure)
  }

  private func makeState(
    _ status: CodingBuddyVoiceConversationStatus
  ) -> ChatComposerVoiceCoachAction.State {
    ChatComposerVoiceCoachAction.State(conversationStatus: status)
  }
}
