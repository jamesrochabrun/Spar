//
//  MCPAppSessionServiceTests.swift
//  CodingBuddyChatTests
//

import BuddyMCPApps
import BuddyMCPUI
import Foundation
import Testing
@testable import CodingBuddyChat

@MainActor
struct MCPAppSessionServiceTests {

  @Test
  func parsesClaudeAndCodexToolNameShapes() {
    // Claude: mcp__<server>__<tool>
    let claude = MCPAppSessionService.parseMCPToolName("mcp__excalidraw__create_view")
    #expect(claude?.server == "excalidraw")
    #expect(claude?.tool == "create_view")

    // Codex item stream: <server>__<tool>
    let codexUnderscore = MCPAppSessionService.parseMCPToolName("excalidraw__create_view")
    #expect(codexUnderscore?.server == "excalidraw")
    #expect(codexUnderscore?.tool == "create_view")

    // Codex alternate: <server>.<tool>
    let codexDot = MCPAppSessionService.parseMCPToolName("excalidraw.create_view")
    #expect(codexDot?.server == "excalidraw")
    #expect(codexDot?.tool == "create_view")

    // Plain tool names are not MCP-qualified.
    #expect(MCPAppSessionService.parseMCPToolName("Bash") == nil)
    #expect(MCPAppSessionService.parseMCPToolName("mcp____") == nil)
  }

  @Test
  func toolResultParsingUnwrapsCodexOkEnvelopeAndToleratesRawText() {
    // Codex wraps successful results in {"Ok": ...}.
    let okWrapped = MCPAppSessionService.parseToolResult(
      #"{"Ok":{"content":[{"type":"text","text":"{\"checkpointId\":\"abc\"}"}]}}"#
    )
    #expect(okWrapped["content"]?.arrayValue?.first?["text"]?.stringValue == #"{"checkpointId":"abc"}"#)

    // Plain JSON objects pass through.
    let object = MCPAppSessionService.parseToolResult(#"{"content":[]}"#)
    #expect(object["content"]?.arrayValue?.isEmpty == true)

    // Non-JSON text becomes a string value instead of being dropped.
    let text = MCPAppSessionService.parseToolResult("plain text result")
    #expect(text.stringValue == "plain text result")
  }

  @Test
  func modelContextTextExtractsContentBlocksAndBareText() {
    // MCP Apps shape: {content:[{type:"text",text}]}.
    let blocks = MCPAppSessionService.modelContextText(from: .object([
      "content": .array([
        .object(["type": .string("text"), "text": .string("user added 2 rectangles")]),
        .object(["type": .string("text"), "text": .string("user moved title")])
      ])
    ]))
    #expect(blocks == "user added 2 rectangles\nuser moved title")

    // Bare {text} fallback.
    let bare = MCPAppSessionService.modelContextText(from: .object(["text": .string("edited")]))
    #expect(bare == "edited")

    #expect(MCPAppSessionService.modelContextText(from: nil) == nil)
    #expect(MCPAppSessionService.modelContextText(from: .object([:])) == nil)
  }

  @Test
  func modelContextIsStoredPerResourceAndConsumedOnce() {
    let service = MCPAppSessionService(discoveryService: NoOpDiscoveryService())
    let resource = MCPAppResource(
      provider: .claude,
      projectPath: "/tmp/ws",
      serverName: "excalidraw",
      source: .liveDiscovery,
      resource: AgentHubMCPUIResource(uri: "ui://excalidraw/mcp-app.html", text: "<main/>")
    )
    let item = MCPAppRenderItem(
      resource: resource,
      invocation: MCPAppInvocation(id: "call-1", serverName: "excalidraw", toolName: "create_view")
    )

    service.noteMCPAppModelContext(resource: resource, params: .object([
      "content": .array([.object(["type": .string("text"), "text": .string("user drew a box")])])
    ]))
    #expect(service.modelContextTextByResourceID[resource.id] == "user drew a box")

    // Duplicate items sharing the resource yield the text once, and reading consumes it.
    let texts = service.consumeModelContextTexts(for: [item, item])
    #expect(texts == ["user drew a box"])
    #expect(service.consumeModelContextTexts(for: [item]).isEmpty)

    // Empty payloads never overwrite or store.
    service.noteMCPAppModelContext(resource: resource, params: .object([:]))
    #expect(service.modelContextTextByResourceID[resource.id] == nil)
  }

  @Test
  func codexInvocationRoundTripProducesRenderableCapture() {
    let service = MCPAppSessionService(discoveryService: NoOpDiscoveryService())

    service.recordToolUse(
      contextKey: "ctx",
      provider: .codex,
      projectPath: "/tmp/ws",
      toolUseId: "call-1",
      toolName: "excalidraw__create_view",
      argumentsJSON: #"{"elements":"[{\"type\":\"text\",\"text\":\"Login Flow\"}]"}"#
    )
    service.recordToolResult(
      contextKey: "ctx",
      toolUseId: "call-1",
      resultJSON: #"{"Ok":{"content":[]}}"#
    )

    let invocations = service.invocationsByContext["ctx"]
    #expect(invocations?.count == 1)
    #expect(invocations?.first?.serverName == "excalidraw")
    #expect(invocations?.first?.toolName == "create_view")
    #expect(invocations?.first?.arguments?["elements"]?.stringValue.map { $0.contains("Login Flow") } == true)
    #expect(invocations?.first?.result?["content"]?.arrayValue?.isEmpty == true)
  }

  // MARK: - Per-session persistence

  @Test
  func fileStoreRoundTripsAndDeletesState() async {
    let store = FileMCPAppInvocationStore(directoryURL: Self.temporaryStoreDirectory())
    let state = StoredWhiteboardSessionState(
      invocations: [
        MCPAppInvocation(
          id: "call-1",
          serverName: "excalidraw",
          toolName: "create_view",
          arguments: .object(["elements": .string(#"[{"type":"text","text":"Login Flow"}]"#)]),
          result: .object(["content": .array([])])
        )
      ],
      checkpointDataById: ["chk-12345678": #"{"elements":[]}"#]
    )

    await store.saveState(state, chatSessionId: "session-1")
    let loaded = await store.loadState(chatSessionId: "session-1")
    #expect(loaded == state)

    await store.deleteState(chatSessionId: "session-1")
    let afterDelete = await store.loadState(chatSessionId: "session-1")
    #expect(afterDelete == StoredWhiteboardSessionState())

    // Unknown sessions load empty rather than failing.
    let missing = await store.loadState(chatSessionId: "never-saved")
    #expect(missing == StoredWhiteboardSessionState())
  }

  @Test
  func fileStoreReadsLegacyBareInvocationArrayFiles() async throws {
    let directory = Self.temporaryStoreDirectory()
    let store = FileMCPAppInvocationStore(directoryURL: directory)
    let invocations = [
      MCPAppInvocation(id: "call-1", serverName: "excalidraw", toolName: "create_view")
    ]

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let legacyData = try JSONEncoder().encode(invocations)
    try legacyData.write(to: directory.appendingPathComponent("session-1.json"))

    let loaded = await store.loadState(chatSessionId: "session-1")
    #expect(loaded.invocations == invocations)
    #expect(loaded.checkpointDataById.isEmpty)
  }

  @Test
  func fileStoreSanitizesSessionIdsForFileNames() {
    #expect(FileMCPAppInvocationStore.sanitized("abc-123_DEF") == "abc-123_DEF")
    #expect(FileMCPAppInvocationStore.sanitized("../../etc/passwd") == "______etc_passwd")
    #expect(FileMCPAppInvocationStore.sanitized("") == "_")
  }

  @Test
  func capturedInvocationsSurviveIntoAFreshServiceViaRestore() async {
    let directory = Self.temporaryStoreDirectory()
    let store = FileMCPAppInvocationStore(directoryURL: directory)

    // Session 1: capture lands before the session id is known, then binds.
    let recording = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: store
    )
    recording.recordToolUse(
      contextKey: "ctx-live",
      provider: .claude,
      projectPath: "/tmp/ws",
      toolUseId: "call-1",
      toolName: "mcp__excalidraw__create_view",
      argumentsJSON: #"{"elements":"[{\"type\":\"text\",\"text\":\"Login Flow\"}]"}"#
    )
    recording.bindChatSession("session-1", contextKey: "ctx-live")
    recording.recordToolResult(
      contextKey: "ctx-live",
      toolUseId: "call-1",
      resultJSON: #"{"content":[]}"#
    )
    await recording.flushPersistence()

    // Relaunch: a fresh service and a fresh context key rehydrate the session.
    let restored = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: store
    )
    await restored.restoreChatSession(
      "session-1",
      contextKey: "ctx-reopened",
      provider: .claude,
      projectPath: "/tmp/ws"
    )

    let invocations = restored.invocationsByContext["ctx-reopened"]
    #expect(invocations?.count == 1)
    #expect(invocations?.first?.id == "call-1")
    #expect(invocations?.first?.serverName == "excalidraw")
    #expect(invocations?.first?.toolName == "create_view")
    #expect(invocations?.first?.result?["content"]?.arrayValue?.isEmpty == true)
  }

  @Test
  func restoreNeverOverwritesLiveCapture() async {
    let store = FileMCPAppInvocationStore(directoryURL: Self.temporaryStoreDirectory())
    await store.saveState(
      StoredWhiteboardSessionState(
        invocations: [MCPAppInvocation(id: "stale", serverName: "excalidraw", toolName: "create_view")]
      ),
      chatSessionId: "session-1"
    )

    let service = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: store
    )
    service.recordToolUse(
      contextKey: "ctx",
      provider: .claude,
      projectPath: "/tmp/ws",
      toolUseId: "live",
      toolName: "mcp__excalidraw__create_view",
      argumentsJSON: nil
    )

    await service.restoreChatSession(
      "session-1",
      contextKey: "ctx",
      provider: .claude,
      projectPath: "/tmp/ws"
    )

    #expect(service.invocationsByContext["ctx"]?.map(\.id) == ["live"])
  }

  @Test
  func restoreReconcilesMissingResultFromTranscriptAndPersistsIt() async {
    let store = FileMCPAppInvocationStore(directoryURL: Self.temporaryStoreDirectory())
    let editedLocal = MCPAppInvocation(
      id: "call-1",
      serverName: "excalidraw",
      toolName: "create_view",
      arguments: .object(["elements": .string("[edited]")]),
      result: nil
    )
    await store.saveState(
      StoredWhiteboardSessionState(invocations: [editedLocal]),
      chatSessionId: "session-1"
    )
    let transcriptOriginal = MCPAppInvocation(
      id: "call-1",
      serverName: "excalidraw",
      toolName: "create_view",
      arguments: .object(["elements": .string("[original]")]),
      result: .string(#"{"checkpointId":"checkpoint-1"}"#)
    )
    let service = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: store,
      transcriptReader: StubTranscriptReader(result: [transcriptOriginal])
    )

    await service.restoreChatSession(
      "session-1",
      contextKey: "ctx",
      provider: .claude,
      projectPath: "/tmp/ws"
    )
    await service.flushPersistence()

    let restored = service.invocationsByContext["ctx"]?.first
    #expect(restored?.arguments?["elements"]?.stringValue == "[edited]")
    #expect(restored?.result?.stringValue == #"{"checkpointId":"checkpoint-1"}"#)
    let durable = await store.loadState(chatSessionId: "session-1")
    #expect(durable.invocations.first?.result?.stringValue == #"{"checkpointId":"checkpoint-1"}"#)
  }

  @Test
  func deleteStoredInvocationsRemovesTheSessionFileAndBinding() async {
    let store = FileMCPAppInvocationStore(directoryURL: Self.temporaryStoreDirectory())
    let service = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: store
    )
    service.bindChatSession("session-1", contextKey: "ctx")
    service.recordToolUse(
      contextKey: "ctx",
      provider: .claude,
      projectPath: "/tmp/ws",
      toolUseId: "call-1",
      toolName: "mcp__excalidraw__create_view",
      argumentsJSON: nil
    )
    await service.flushPersistence()

    await service.deleteStoredInvocations(chatSessionId: "session-1")
    let remaining = await store.loadState(chatSessionId: "session-1")
    #expect(remaining.invocations.isEmpty)

    // The binding is gone, so later captures no longer persist under the id.
    service.recordToolResult(contextKey: "ctx", toolUseId: "call-1", resultJSON: nil)
    await service.flushPersistence()
    let afterRecord = await store.loadState(chatSessionId: "session-1")
    #expect(afterRecord.invocations.isEmpty)
  }

  // MARK: - User-edit (checkpoint) persistence

  private static let checkpointId = "chk-abc12345"

  /// A service with one captured create_view whose result carries a checkpoint id,
  /// mirroring the shape Claude stores (result text is a JSON string).
  private func makeServiceWithDrawnView(store: FileMCPAppInvocationStore) -> MCPAppSessionService {
    let service = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: store
    )
    service.bindChatSession("session-1", contextKey: "ctx")
    service.recordToolUse(
      contextKey: "ctx",
      provider: .claude,
      projectPath: "/tmp/ws",
      toolUseId: "call-1",
      toolName: "mcp__excalidraw__create_view",
      argumentsJSON: #"{"elements":"[{\"type\":\"text\",\"text\":\"Login Flow\"}]"}"#
    )
    service.recordToolResult(
      contextKey: "ctx",
      toolUseId: "call-1",
      resultJSON: #"{"content":[{"type":"text","text":"{\"checkpointId\":\"\#(Self.checkpointId)\"}"}]}"#
    )
    return service
  }

  private var whiteboardResource: MCPAppResource {
    MCPAppResource(
      provider: .claude,
      projectPath: "/tmp/ws",
      serverName: "excalidraw",
      source: .liveDiscovery,
      resource: AgentHubMCPUIResource(uri: "ui://excalidraw/mcp-app.html", text: "<main/>")
    )
  }

  @Test
  func savedCheckpointRewritesTheOriginatingInvocationAndPersists() async throws {
    let store = FileMCPAppInvocationStore(directoryURL: Self.temporaryStoreDirectory())
    let service = makeServiceWithDrawnView(store: store)

    // The rendered app saves the user's edited canvas through the bridge.
    let edited = #"{"elements":[{"type":"text","text":"Login Flow (edited)"}]}"#
    _ = try await service.callMCPAppTool(
      resource: whiteboardResource,
      name: "save_checkpoint",
      arguments: .object(["id": .string(Self.checkpointId), "data": .string(edited)])
    )

    // The in-memory invocation now replays the edited elements.
    let live = service.invocationsByContext["ctx"]?.first
    #expect(live?.arguments?["elements"]?.stringValue?.contains("Login Flow (edited)") == true)

    // And a fresh service after relaunch restores the edited state too.
    await service.flushPersistence()
    let restored = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: store
    )
    await restored.restoreChatSession(
      "session-1",
      contextKey: "ctx-reopened",
      provider: .claude,
      projectPath: "/tmp/ws"
    )
    let invocation = restored.invocationsByContext["ctx-reopened"]?.first
    #expect(invocation?.arguments?["elements"]?.stringValue?.contains("Login Flow (edited)") == true)
  }

  @Test
  func readCheckpointIsServedFromTheLocalCaptureAcrossRelaunch() async throws {
    let store = FileMCPAppInvocationStore(directoryURL: Self.temporaryStoreDirectory())
    let service = makeServiceWithDrawnView(store: store)

    let edited = #"{"elements":[{"type":"rectangle","id":"r1"}]}"#
    _ = try await service.callMCPAppTool(
      resource: whiteboardResource,
      name: "save_checkpoint",
      arguments: .object(["id": .string(Self.checkpointId), "data": .string(edited)])
    )
    await service.flushPersistence()

    // Relaunch: the remote server may have forgotten the checkpoint; the local
    // capture serves the read in the exact server result shape.
    let restored = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: store
    )
    await restored.restoreChatSession(
      "session-1",
      contextKey: "ctx-reopened",
      provider: .claude,
      projectPath: "/tmp/ws"
    )
    let result = try await restored.callMCPAppTool(
      resource: whiteboardResource,
      name: "read_checkpoint",
      arguments: .object(["id": .string(Self.checkpointId)])
    )
    #expect(result["content"]?.arrayValue?.first?["text"]?.stringValue == edited)
  }

  @Test
  func checkpointForUnknownInvocationIsCachedButNotPersisted() async throws {
    let store = FileMCPAppInvocationStore(directoryURL: Self.temporaryStoreDirectory())
    let service = makeServiceWithDrawnView(store: store)

    _ = try await service.callMCPAppTool(
      resource: whiteboardResource,
      name: "save_checkpoint",
      arguments: .object(["id": .string("chk-unmatched-99"), "data": .string(#"{"elements":[]}"#)])
    )
    await service.flushPersistence()

    // Served from the in-memory cache for this run...
    let result = try await service.callMCPAppTool(
      resource: whiteboardResource,
      name: "read_checkpoint",
      arguments: .object(["id": .string("chk-unmatched-99")])
    )
    #expect(result["content"]?.arrayValue?.first?["text"]?.stringValue == #"{"elements":[]}"#)

    // ...but never written into a session it does not belong to.
    let stored = await store.loadState(chatSessionId: "session-1")
    #expect(stored.checkpointDataById["chk-unmatched-99"] == nil)
  }

  @Test
  func resumeReplayOfTheSameToolUseNeverRevertsUserEdits() async throws {
    let store = FileMCPAppInvocationStore(directoryURL: Self.temporaryStoreDirectory())
    let service = makeServiceWithDrawnView(store: store)

    // The user edits; the checkpoint save folds the edits into the invocation.
    let edited = #"{"elements":[{"type":"text","text":"Login Flow (edited)"}]}"#
    _ = try await service.callMCPAppTool(
      resource: whiteboardResource,
      name: "save_checkpoint",
      arguments: .object(["id": .string(Self.checkpointId), "data": .string(edited)])
    )

    // The provider resumes the session and replays the ORIGINAL tool_use event
    // with the same tool_use id. It must not clobber the edited arguments.
    service.recordToolUse(
      contextKey: "ctx",
      provider: .claude,
      projectPath: "/tmp/ws",
      toolUseId: "call-1",
      toolName: "mcp__excalidraw__create_view",
      argumentsJSON: #"{"elements":"[{\"type\":\"text\",\"text\":\"Login Flow\"}]"}"#
    )

    let invocation = service.invocationsByContext["ctx"]?.first
    #expect(service.invocationsByContext["ctx"]?.count == 1)
    #expect(invocation?.arguments?["elements"]?.stringValue?.contains("Login Flow (edited)") == true)
    // The replayed result still lands (same value, harmless).
    service.recordToolResult(
      contextKey: "ctx",
      toolUseId: "call-1",
      resultJSON: #"{"content":[{"type":"text","text":"{\"checkpointId\":\"\#(Self.checkpointId)\"}"}]}"#
    )
    #expect(service.invocationsByContext["ctx"]?.first?.result != nil)
  }

  @Test
  func networkGrantsPersistAcrossServiceInstances() {
    let directory = Self.temporaryStoreDirectory()
    let grantStore = FileMCPAppGrantStore(
      fileURL: directory.appendingPathComponent("grants.json")
    )

    let service = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: FileMCPAppInvocationStore(directoryURL: directory),
      grantStore: grantStore
    )
    #expect(!service.isMCPAppNetworkGranted(serverName: "excalidraw", hosts: ["esm.sh"]))
    service.grantMCPAppNetwork(serverName: "excalidraw", hosts: ["esm.sh"])

    // A fresh service (relaunch) loads the network grant from disk.
    let relaunched = MCPAppSessionService(
      discoveryService: NoOpDiscoveryService(),
      invocationStore: FileMCPAppInvocationStore(directoryURL: directory),
      grantStore: grantStore
    )
    #expect(relaunched.isMCPAppNetworkGranted(serverName: "excalidraw", hosts: ["esm.sh"]))

    // Ungranted network identities still prompt.
    #expect(!relaunched.isMCPAppNetworkGranted(serverName: "excalidraw", hosts: ["evil.example"]))

    // A missing grants file loads empty instead of failing.
    let emptyStore = FileMCPAppGrantStore(
      fileURL: directory.appendingPathComponent("never-written.json")
    )
    #expect(emptyStore.load() == MCPAppGrantRecord())
  }

  @Test
  func checkpointArgumentRewriteReplacesElementsAndKeepsOtherArguments() {
    let rewritten = MCPAppSessionService.arguments(
      .object(["elements": .string("[]"), "theme": .string("dark")]),
      replacingElementsWith: #"{"elements":[{"type":"ellipse"}]}"#
    )
    #expect(rewritten?["theme"]?.stringValue == "dark")
    #expect(rewritten?["elements"]?.stringValue?.contains("ellipse") == true)

    // Malformed checkpoint data leaves the invocation untouched.
    #expect(MCPAppSessionService.arguments(.object([:]), replacingElementsWith: "not json") == nil)
  }

  private static func temporaryStoreDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("MCPAppInvocationStoreTests-\(UUID().uuidString)", isDirectory: true)
  }
}

private struct NoOpDiscoveryService: MCPAppDiscoveryServiceProtocol {
  func callTool(
    provider: SessionProviderKind, projectPath: String, serverName: String,
    name: String, arguments: AgentHubMCPUIJSONValue?
  ) async throws -> AgentHubMCPUIJSONValue { .object([:]) }

  func readResource(
    provider: SessionProviderKind, projectPath: String, serverName: String, uri: String
  ) async throws -> AgentHubMCPUIJSONValue { .object([:]) }

  func listResources(
    provider: SessionProviderKind, projectPath: String, serverName: String
  ) async throws -> AgentHubMCPUIJSONValue { .object([:]) }

  func listTools(
    provider: SessionProviderKind, projectPath: String, serverName: String
  ) async throws -> AgentHubMCPUIJSONValue { .object([:]) }
}

private struct StubTranscriptReader: MCPAppInvocationTranscriptReading {
  let result: [MCPAppInvocation]

  func invocations(
    provider: SessionProviderKind,
    projectPath: String,
    chatSessionId: String
  ) async -> [MCPAppInvocation] {
    result
  }
}
