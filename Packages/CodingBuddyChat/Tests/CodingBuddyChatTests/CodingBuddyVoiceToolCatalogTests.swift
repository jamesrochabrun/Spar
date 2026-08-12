import AgentHubVoice
import Foundation
import Testing
@testable import CodingBuddyChat

@MainActor
struct CodingBuddyVoiceToolCatalogTests {
  @Test
  func exposesReadOnlySessionAndWorkspaceToolsWithoutMessageSending() async {
    let defaults = makeDefaults()
    let session = MockSession()
    let catalog = CodingBuddyVoiceToolCatalog(
      session: session,
      engine: RealtimeVoiceEngine(permissionRequester: { true }),
      workspaceReader: MockWorkspaceReader(),
      defaults: defaults
    )
    let registry = VoiceToolRegistry(tools: catalog.makeTools())
    let names = Set(registry.tools.map(\.name))

    #expect(names.contains("list_sessions"))
    #expect(names.contains("read_session_history"))
    #expect(names.contains("list_workspace_files"))
    #expect(names.contains("read_workspace_file"))
    #expect(!names.contains("send_prompt"))

    let unknownSend = await registry.execute(
      name: "send_prompt",
      arguments: #"{"session_id":"codingbuddy.active-session","prompt":"Explain"}"#
    )
    #expect(unknownSend.contains("unknown_tool"))
    #expect(session.dictationDeliveries.isEmpty)
  }

  @Test
  func readsActiveWorkspaceWithoutMutatingTheChat() async {
    let session = MockSession()
    let catalog = CodingBuddyVoiceToolCatalog(
      session: session,
      engine: RealtimeVoiceEngine(permissionRequester: { true }),
      workspaceReader: MockWorkspaceReader(),
      defaults: makeDefaults()
    )
    let registry = VoiceToolRegistry(
      tools: catalog.makeTools()
    )

    let list = await registry.execute(
      name: "list_workspace_files",
      arguments: #"{"session_id":"codingbuddy.active-session"}"#
    )
    #expect(list.contains("Solution.swift"))

    let file = await registry.execute(
      name: "read_workspace_file",
      arguments: #"{"session_id":"codingbuddy.active-session","path":"Solution.swift"}"#
    )
    #expect(file.contains("func twoSum"))
    #expect(session.dictationDeliveries.isEmpty)
  }

  @Test
  func rejectsAStaleTargetForWorkspaceReads() async {
    let session = MockSession()
    let catalog = CodingBuddyVoiceToolCatalog(
      session: session,
      engine: RealtimeVoiceEngine(permissionRequester: { true }),
      workspaceReader: MockWorkspaceReader(),
      defaults: makeDefaults()
    )
    let registry = VoiceToolRegistry(
      tools: catalog.makeTools()
    )

    let result = await registry.execute(
      name: "read_workspace_file",
      arguments: #"{"session_id":"old-session","path":"Solution.swift"}"#
    )

    #expect(result.contains("not_found"))
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "CodingBuddyVoiceToolCatalogTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    defaults.set(false, forKey: CodingBuddyVoiceDefaults.screenCaptureEnabled)
    return defaults
  }

  @MainActor
  private final class MockSession: CodingBuddyVoiceSessionProviding {
    var voiceSessionSnapshot: CodingBuddyVoiceSessionSnapshot? = .init(
      id: CodingBuddyVoiceHUDHost.targetID,
      name: "Two Sum",
      mode: "Practice",
      provider: "Claude",
      status: "Ready",
      questionTitle: "Two Sum",
      questionPrompt: "Return the two indices.",
      workspacePath: "/tmp/two-sum",
      recentTurns: []
    )
    var voiceLatestResponse: String? = "Use a hash map."
    var dictationDeliveries: [String] = []

    func deliverDictation(
      _ prompt: String,
      autoSubmit: Bool
    ) -> CodingBuddyVoicePromptOutcome {
      dictationDeliveries.append(prompt)
      return .accepted
    }
  }

  private struct MockWorkspaceReader: CodingBuddyVoiceWorkspaceReading {
    func listEntries(
      in workspacePath: String,
      relativePath: String?
    ) async throws -> [CodingBuddyVoiceWorkspaceEntry] {
      [.init(path: "Solution.swift", kind: "file", size: 42)]
    }

    func readFile(
      in workspacePath: String,
      relativePath: String,
      characterLimit: Int
    ) async throws -> String {
      "func twoSum() {}"
    }
  }
}
