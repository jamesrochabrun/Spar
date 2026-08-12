import AgentHubVoice
import AgentHubVoicePanel
import Testing
@testable import CodingBuddyChat

struct CodingBuddyVoiceConversationStatusTests {
  @Test
  func voiceRequiresBothTheFeatureAndAnActiveSession() {
    #expect(makeStatus(isEnabled: false) == .disabled)
    #expect(makeStatus(isSessionAvailable: false) == .unavailable)
  }

  @Test
  func conversationStatesExposeCompactToolbarFeedback() {
    #expect(makeStatus(realtimeState: .connecting) == .connecting)
    #expect(makeStatus(realtimeState: .idle) == .listening)
    #expect(
      makeStatus(realtimeState: .idle, isMicrophoneMuted: true) == .muted
    )
    #expect(makeStatus(realtimeState: .userSpeaking) == .userSpeaking)
    #expect(makeStatus(realtimeState: .thinking) == .thinking)
    #expect(makeStatus(realtimeState: .speaking) == .speaking)
    #expect(makeStatus(realtimeState: .speaking).title == "Spar speaking")
    #expect(
      makeStatus(realtimeState: .executingTool("read_workspace_file"))
        == .executingTool("read_workspace_file")
    )
    #expect(
      makeStatus(realtimeState: .executingTool("read_workspace_file")).detail
        == "Using read_workspace_file"
    )
  }

  @Test
  func dictationModeLeavesTheConversationControlReady() {
    let status = makeStatus(mode: .dictate, realtimeState: .idle)

    #expect(status == .ready)
    #expect(!status.isActive)
  }

  @Test
  func failuresPreserveTheUserFacingError() {
    let status = makeStatus(realtimeState: .failed("Missing API key"))

    #expect(status == .failed("Missing API key"))
    #expect(status.detail == "Missing API key")
    #expect(!status.isActive)
  }

  private func makeStatus(
    isEnabled: Bool = true,
    isSessionAvailable: Bool = true,
    mode: VoiceHUDMode = .converse,
    realtimeState: VoiceEngineState = .disconnected,
    isMicrophoneMuted: Bool = false
  ) -> CodingBuddyVoiceConversationStatus {
    CodingBuddyVoiceConversationStatus(
      isEnabled: isEnabled,
      isSessionAvailable: isSessionAvailable,
      mode: mode,
      realtimeState: realtimeState,
      isMicrophoneMuted: isMicrophoneMuted,
      isMicrophoneGated: false,
      isMicrophoneStandbyMuted: false
    )
  }
}
