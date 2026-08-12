import Testing
@testable import CodingBuddyChat

struct CodingBuddyVoiceSessionContextBuilderTests {
  @Test
  func includesProblemProviderWorkspaceAndSharedTranscript() throws {
    let snapshot = CodingBuddyVoiceSessionSnapshot(
      id: "active",
      name: "LRU Cache",
      mode: "Mock Interview",
      provider: "Codex",
      status: "Ready",
      questionTitle: "LRU Cache",
      questionPrompt: "Design an LRU cache with O(1) access.",
      workspacePath: "/tmp/lru-cache",
      recentTurns: [
        CodingBuddyVoiceTurn(role: "user", text: "I will use a dictionary."),
        CodingBuddyVoiceTurn(role: "assistant", text: "How will you track recency?"),
      ]
    )

    let context = try #require(
      CodingBuddyVoiceSessionContextBuilder.make(snapshot: snapshot)
    )

    #expect(context.contains("Chat provider: Codex"))
    #expect(context.contains("Design an LRU cache"))
    #expect(context.contains("Workspace: /tmp/lru-cache"))
    #expect(context.contains("Assistant: How will you track recency?"))
  }

  @Test
  func limitsLongTurnsAndTotalContext() throws {
    let longText = String(repeating: "x", count: 8_000)
    let snapshot = CodingBuddyVoiceSessionSnapshot(
      id: "active",
      name: "Practice session",
      mode: "Practice",
      provider: "Local / API",
      status: "Ready",
      questionTitle: nil,
      questionPrompt: longText,
      workspacePath: nil,
      recentTurns: [CodingBuddyVoiceTurn(role: "user", text: longText)]
    )

    let context = try #require(
      CodingBuddyVoiceSessionContextBuilder.make(snapshot: snapshot)
    )

    #expect(context.count <= CodingBuddyVoiceSessionContextBuilder.maximumCharacters + 1)
    #expect(context.contains("…"))
  }
}
