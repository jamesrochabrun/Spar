import AgentHubVoice
import Foundation
import Testing
@testable import CodingBuddyChat

@MainActor
struct CodingBuddyVoiceHUDHostTests {
  @Test
  func dictationCanPopulateTheSharedChatComposerWithoutSubmitting() {
    let defaults = makeDefaults()
    defaults.set(false, forKey: CodingBuddyVoiceDefaults.autoSubmitDictation)
    let session = MockSession()
    session.outcome = .insertedIntoComposer
    let host = makeHost(session: session, defaults: defaults)

    let outcome = host.deliverDictation(
      "Explain the failing test",
      to: CodingBuddyVoiceHUDHost.targetID
    )

    #expect(outcome == .delivered)
    #expect(session.deliveries == [
      Delivery(prompt: "Explain the failing test", autoSubmit: false)
    ])
  }

  @Test
  func dictationCanSubmitToTheSharedChatWhenEnabled() {
    let defaults = makeDefaults()
    defaults.set(true, forKey: CodingBuddyVoiceDefaults.autoSubmitDictation)
    let session = MockSession()
    let host = makeHost(session: session, defaults: defaults)

    let outcome = host.deliverDictation(
      "Review my latest solution",
      to: CodingBuddyVoiceHUDHost.targetID
    )

    #expect(outcome == .delivered)
    #expect(session.deliveries == [
      Delivery(prompt: "Review my latest solution", autoSubmit: true)
    ])
  }

  @Test
  func realtimeInstructionsDefineAReadOnlyIndependentSideBuddy() {
    let host = makeHost(session: MockSession(), defaults: makeDefaults())
    let instructions = host.makeRealtimeInstructions() ?? ""

    #expect(instructions.contains("read-only side buddy"))
    #expect(instructions.contains("Claude, Codex"))
    #expect(instructions.contains("Local/API"))
    #expect(instructions.contains("never send messages"))
    #expect(instructions.contains("inspect it yourself"))
    #expect(!instructions.contains("send_prompt"))
  }

  private func makeHost(
    session: MockSession,
    defaults: UserDefaults
  ) -> CodingBuddyVoiceHUDHost {
    CodingBuddyVoiceHUDHost(
      session: session,
      engine: RealtimeVoiceEngine(permissionRequester: { true }),
      keyProvider: OpenAIKeyProvider(store: InMemorySecretsStore()),
      defaults: defaults
    )
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "CodingBuddyVoiceHUDHostTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    CodingBuddyVoiceDefaults.register(in: defaults)
    return defaults
  }

  private struct Delivery: Equatable {
    let prompt: String
    let autoSubmit: Bool
  }

  @MainActor
  private final class MockSession: CodingBuddyVoiceSessionProviding {
    var voiceSessionSnapshot: CodingBuddyVoiceSessionSnapshot? = .init(
      id: CodingBuddyVoiceHUDHost.targetID,
      name: "Current problem",
      mode: "Practice",
      provider: "Local / API",
      status: "Ready",
      questionTitle: nil,
      questionPrompt: nil,
      workspacePath: nil,
      recentTurns: []
    )
    var voiceLatestResponse: String?
    var outcome: CodingBuddyVoicePromptOutcome = .accepted
    var deliveries: [Delivery] = []

    func deliverDictation(
      _ prompt: String,
      autoSubmit: Bool
    ) -> CodingBuddyVoicePromptOutcome {
      deliveries.append(Delivery(prompt: prompt, autoSubmit: autoSubmit))
      return outcome
    }
  }
}
