//
//  MCPAppInvocationTranscriptReader.swift
//  CodingBuddyChat
//
//  Rebuilds MCP app invocations from Claude's persisted JSONL transcript.
//  This mirrors AgentHub's source-of-truth path: live SDK callbacks are useful
//  for immediacy, but the transcript is what reliably correlates tool_use ids
//  with tool_result ids across relaunches and provider resume/replay.
//

import BuddyMCPApps
import BuddyMCPUI
import Foundation

public protocol MCPAppInvocationTranscriptReading: Sendable {
  func invocations(
    provider: SessionProviderKind,
    projectPath: String,
    chatSessionId: String
  ) async -> [MCPAppInvocation]
}

struct FileMCPAppInvocationTranscriptReader: MCPAppInvocationTranscriptReading {
  private let claudeProjectsDirectory: URL

  init(claudeProjectsDirectory: URL? = nil) {
    self.claudeProjectsDirectory = claudeProjectsDirectory
      ?? URL.homeDirectory
        .appending(path: ".claude", directoryHint: .isDirectory)
        .appending(path: "projects", directoryHint: .isDirectory)
  }

  func invocations(
    provider: SessionProviderKind,
    projectPath: String,
    chatSessionId: String
  ) async -> [MCPAppInvocation] {
    guard provider == .claude,
          let transcriptURL = transcriptURL(
            projectPath: projectPath,
            chatSessionId: chatSessionId
          ),
          let contents = try? String(contentsOf: transcriptURL, encoding: .utf8) else {
      return []
    }
    return Self.parseJSONL(contents)
  }

  private func transcriptURL(projectPath: String, chatSessionId: String) -> URL? {
    guard chatSessionId.unicodeScalars.allSatisfy({
      CharacterSet.alphanumerics.union(.init(charactersIn: "-_")).contains($0)
    }) else {
      return nil
    }

    let encodedProjectPath = projectPath
      .replacing("/", with: "-")
      .replacing(".", with: "-")
      .replacing("_", with: "-")
    let expected = claudeProjectsDirectory
      .appending(path: encodedProjectPath, directoryHint: .isDirectory)
      .appending(path: "\(chatSessionId).jsonl")
    if FileManager.default.fileExists(atPath: expected.path) {
      return expected
    }

    // Claude's path encoding has changed before. Session ids are globally
    // unique, so fall back to finding the matching file in any project folder.
    guard let projectDirectories = try? FileManager.default.contentsOfDirectory(
      at: claudeProjectsDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return nil
    }
    return projectDirectories
      .lazy
      .map { $0.appending(path: "\(chatSessionId).jsonl") }
      .first { FileManager.default.fileExists(atPath: $0.path) }
  }

  static func parseJSONL(_ contents: String) -> [MCPAppInvocation] {
    var orderedIDs: [String] = []
    var invocationsByID: [String: MCPAppInvocation] = [:]

    for line in contents.split(whereSeparator: \.isNewline) {
      guard let data = String(line).data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = root["message"] as? [String: Any],
            let content = message["content"] as? [[String: Any]] else {
        continue
      }

      for block in content {
        switch block["type"] as? String {
        case "tool_use":
          guard let id = block["id"] as? String,
                let name = block["name"] as? String,
                let parsed = MCPAppSessionService.parseMCPToolName(name) else {
            continue
          }
          if invocationsByID[id] == nil {
            orderedIDs.append(id)
          }
          let previousResult = invocationsByID[id]?.result
          invocationsByID[id] = MCPAppInvocation(
            id: id,
            serverName: parsed.server,
            toolName: parsed.tool,
            arguments: block["input"].map(AgentHubMCPUIJSONValue.init(any:)),
            result: previousResult
          )

        case "tool_result":
          guard let id = block["tool_use_id"] as? String,
                let pending = invocationsByID[id] else {
            continue
          }
          invocationsByID[id] = MCPAppInvocation(
            id: pending.id,
            serverName: pending.serverName,
            toolName: pending.toolName,
            arguments: pending.arguments,
            result: block["content"].map(AgentHubMCPUIJSONValue.init(any:))
          )

        default:
          continue
        }
      }
    }

    return orderedIDs.compactMap { invocationsByID[$0] }
  }
}
