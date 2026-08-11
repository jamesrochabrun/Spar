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
