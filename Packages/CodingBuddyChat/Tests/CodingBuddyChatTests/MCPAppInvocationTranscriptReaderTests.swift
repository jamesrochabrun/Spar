import BuddyMCPApps
import Foundation
import Testing

@testable import CodingBuddyChat

@Suite("MCP app transcript reconciliation")
struct MCPAppInvocationTranscriptReaderTests {
  @Test("Claude JSONL correlates create_view with its checkpoint result")
  func parsesProductionShapedClaudeJSONL() {
    let jsonl = #"""
    {"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_create","name":"mcp__excalidraw__create_view","input":{"elements":"[{\"type\":\"text\",\"text\":\"Original\"}]"}}]}}
    {"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_create","type":"tool_result","content":"{\"checkpointId\":\"9610dec1177f4144bb\"}"}]}}
    """#

    let invocations = FileMCPAppInvocationTranscriptReader.parseJSONL(jsonl)

    #expect(invocations.count == 1)
    #expect(invocations[0].id == "toolu_create")
    #expect(invocations[0].serverName == "excalidraw")
    #expect(invocations[0].toolName == "create_view")
    #expect(invocations[0].arguments?["elements"]?.stringValue?.contains("Original") == true)
    #expect(invocations[0].result?.stringValue == #"{"checkpointId":"9610dec1177f4144bb"}"#)
  }

  @Test("Reader locates a session transcript under Claude's encoded project path")
  func readsTranscriptFromEncodedProjectDirectory() async throws {
    let projectsDirectory = FileManager.default.temporaryDirectory
      .appending(path: "ClaudeProjects-\(UUID().uuidString)", directoryHint: .isDirectory)
    let projectPath = "/tmp/whiteboard_project"
    let encoded = "-tmp-whiteboard-project"
    let sessionDirectory = projectsDirectory.appending(path: encoded, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
    let transcript = #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"tu1","name":"mcp__excalidraw__create_view","input":{"elements":"[]"}}]}}"#
    try transcript.write(
      to: sessionDirectory.appending(path: "session-1.jsonl"),
      atomically: true,
      encoding: .utf8
    )

    let reader = FileMCPAppInvocationTranscriptReader(
      claudeProjectsDirectory: projectsDirectory
    )
    let invocations = await reader.invocations(
      provider: .claude,
      projectPath: projectPath,
      chatSessionId: "session-1"
    )

    #expect(invocations.map(\.id) == ["tu1"])
  }

  @Test("Merge fills a missing result without replacing locally edited elements")
  @MainActor
  func mergePreservesLocalEditsAndAddsTranscriptResult() {
    let local = MCPAppInvocation(
      id: "tu1",
      serverName: "excalidraw",
      toolName: "create_view",
      arguments: .object(["elements": .string("[edited]")]),
      result: nil
    )
    let transcript = MCPAppInvocation(
      id: "tu1",
      serverName: "excalidraw",
      toolName: "create_view",
      arguments: .object(["elements": .string("[original]")]),
      result: .string(#"{"checkpointId":"abc"}"#)
    )

    let merged = MCPAppSessionService.mergeInvocations(
      local: [local],
      transcript: [transcript]
    )

    #expect(merged[0].arguments?["elements"]?.stringValue == "[edited]")
    #expect(merged[0].result?.stringValue == #"{"checkpointId":"abc"}"#)
  }
}
