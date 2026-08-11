//
//  MCPAppRealPayloadPersistenceTests.swift
//  CodingBuddyChatTests
//
//  Drives the whiteboard persistence pipeline with a production-shaped
//  excalidraw payload (captured from a real session transcript) to guarantee
//  the encode/write path holds for real data, not just fixtures.
//

import BuddyMCPApps
import BuddyMCPUI
import Foundation
import Testing
@testable import CodingBuddyChat

@MainActor
struct MCPAppRealPayloadPersistenceTests {

  /// Verbatim shape of a real `mcp__excalidraw__create_view` input: an
  /// `elements` argument holding a pretty-printed JSON array string.
  private static let realArgumentsJSON = #"""
  {"elements": "[\n  {\"type\":\"cameraUpdate\",\"width\":800,\"height\":600,\"x\":0,\"y\":0},\n  {\"type\":\"text\",\"id\":\"title\",\"x\":180,\"y\":40,\"text\":\"Photo Feed - iOS Client Design\",\"fontSize\":28,\"strokeColor\":\"#1e1e1e\"},\n  {\"type\":\"rectangle\",\"id\":\"reqZone\",\"x\":80,\"y\":120,\"width\":640,\"height\":420,\"roundness\":{\"type\":3},\"strokeColor\":\"#4a9eed\",\"strokeWidth\":2,\"strokeStyle\":\"dashed\",\"backgroundColor\":\"#dbe4ff\",\"fillStyle\":\"solid\",\"opacity\":25},\n  {\"type\":\"text\",\"id\":\"reqLabel\",\"x\":100,\"y\":140,\"text\":\"Requirements\",\"fontSize\":20,\"strokeColor\":\"#2563eb\"}\n]"}
  """#

  /// Claude stores the tool result as a JSON *string* (note the quoting).
  private static let realResultJSON = #""{\"checkpointId\":\"ab7d9fc4a07d4489b4\"}""#

  @Test
  func productionShapedPayloadPersistsAndRestores() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("MCPAppRealPayload-\(UUID().uuidString)", isDirectory: true)
    let store = FileMCPAppInvocationStore(directoryURL: directory)

    let service = MCPAppSessionService(
      discoveryService: RealPayloadNoOpDiscovery(),
      invocationStore: store,
      grantStore: FileMCPAppGrantStore(fileURL: directory.appendingPathComponent("grants.json"))
    )
    service.bindChatSession("real-session", contextKey: "ctx")
    service.recordToolUse(
      contextKey: "ctx",
      provider: .claude,
      projectPath: "/tmp/ws",
      toolUseId: "toolu_real_1",
      toolName: "mcp__excalidraw__create_view",
      argumentsJSON: Self.realArgumentsJSON
    )
    service.recordToolResult(
      contextKey: "ctx",
      toolUseId: "toolu_real_1",
      resultJSON: Self.realResultJSON
    )
    await service.flushPersistence()

    // The session file must exist on disk with the full payload.
    let fileURL = directory.appendingPathComponent("real-session.json")
    #expect(FileManager.default.fileExists(atPath: fileURL.path))

    // The user edits: save_checkpoint arrives with the checkpoint id from the
    // string-shaped result. It must match, rewrite, and persist.
    let edited = #"{"elements":[{"type":"text","id":"user1","x":1,"y":2,"text":"user note"}]}"#
    _ = try await service.callMCPAppTool(
      resource: MCPAppResource(
        provider: .claude,
        projectPath: "/tmp/ws",
        serverName: "excalidraw",
        source: .liveDiscovery,
        resource: AgentHubMCPUIResource(uri: "ui://excalidraw/mcp-app.html", text: "<main/>")
      ),
      name: "save_checkpoint",
      arguments: .object(["id": .string("ab7d9fc4a07d4489b4"), "data": .string(edited)])
    )
    await service.flushPersistence()

    let restored = MCPAppSessionService(
      discoveryService: RealPayloadNoOpDiscovery(),
      invocationStore: store,
      grantStore: FileMCPAppGrantStore(fileURL: directory.appendingPathComponent("grants.json"))
    )
    await restored.restoreChatSession(
      "real-session",
      contextKey: "ctx2",
      provider: .claude,
      projectPath: "/tmp/ws"
    )
    let invocation = restored.invocationsByContext["ctx2"]?.first
    #expect(invocation?.arguments?["elements"]?.stringValue?.contains("user note") == true)
  }
}

private struct RealPayloadNoOpDiscovery: MCPAppDiscoveryServiceProtocol {
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
