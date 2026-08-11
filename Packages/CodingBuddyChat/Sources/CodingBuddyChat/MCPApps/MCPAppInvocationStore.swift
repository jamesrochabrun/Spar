//
//  MCPAppInvocationStore.swift
//  CodingBuddyChat
//
//  Per-session persistence for captured MCP app invocations (the whiteboard's
//  seed data). AgentHub rehydrates these from the CLI's JSONL transcript on
//  every parse; this app owns its session store and supports providers with no
//  on-disk transcript (Local/API), so the captured invocations are persisted
//  here directly, keyed by chat session id, and reloaded on session switch.
//

import BuddyMCPApps
import ClaudeCodeCore
import Foundation
import os

private let storeLog = Logger(subsystem: "com.codingbuddy.mcp", category: "WhiteboardStore")

/// A session's whiteboard state: the agent's app invocations (with any user
/// edits folded into their arguments) plus the raw checkpoint payloads the
/// rendered app saved through the host bridge, so `read_checkpoint` can be
/// served locally when the remote server no longer has them.
public struct StoredWhiteboardSessionState: Codable, Sendable, Equatable {
  public var invocations: [MCPAppInvocation]
  public var checkpointDataById: [String: String]

  public init(
    invocations: [MCPAppInvocation] = [],
    checkpointDataById: [String: String] = [:]
  ) {
    self.invocations = invocations
    self.checkpointDataById = checkpointDataById
  }
}

public protocol MCPAppInvocationStoring: Sendable {
  func loadState(chatSessionId: String) async -> StoredWhiteboardSessionState
  func saveState(_ state: StoredWhiteboardSessionState, chatSessionId: String) async
  func deleteState(chatSessionId: String) async
}

/// File-backed store: one JSON file per chat session in a
/// `WhiteboardInvocations` folder inside the app's Application Support
/// directory, alongside the SQLite databases.
public actor FileMCPAppInvocationStore: MCPAppInvocationStoring {

  private let directoryURL: URL

  public init(directoryURL: URL? = nil) {
    self.directoryURL = directoryURL ?? AppStorageLocations.applicationSupportDirectory()
      .appendingPathComponent("WhiteboardInvocations", isDirectory: true)
  }

  public func loadState(chatSessionId: String) async -> StoredWhiteboardSessionState {
    guard let data = try? Data(contentsOf: fileURL(for: chatSessionId)) else {
      storeLog.notice("load miss session=\(chatSessionId, privacy: .public)")
      return StoredWhiteboardSessionState()
    }
    if let state = try? JSONDecoder().decode(StoredWhiteboardSessionState.self, from: data) {
      storeLog.notice("load hit session=\(chatSessionId, privacy: .public) invocations=\(state.invocations.count) checkpoints=\(state.checkpointDataById.count)")
      return state
    }
    // Legacy format: a bare invocation array, before checkpoints were stored.
    if let invocations = try? JSONDecoder().decode([MCPAppInvocation].self, from: data) {
      return StoredWhiteboardSessionState(invocations: invocations)
    }
    storeLog.error("load undecodable session=\(chatSessionId, privacy: .public) bytes=\(data.count)")
    return StoredWhiteboardSessionState()
  }

  public func saveState(_ state: StoredWhiteboardSessionState, chatSessionId: String) async {
    guard !chatSessionId.isEmpty else { return }
    do {
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      let data = try JSONEncoder().encode(state)
      try data.write(to: fileURL(for: chatSessionId), options: .atomic)
      storeLog.notice("save ok session=\(chatSessionId, privacy: .public) invocations=\(state.invocations.count) checkpoints=\(state.checkpointDataById.count) bytes=\(data.count)")
    } catch {
      // Best-effort, but loudly: a failing save is exactly the bug report
      // "my whiteboard reverts on relaunch".
      storeLog.error("save FAILED session=\(chatSessionId, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
    }
  }

  public func deleteState(chatSessionId: String) async {
    try? FileManager.default.removeItem(at: fileURL(for: chatSessionId))
  }

  private func fileURL(for chatSessionId: String) -> URL {
    directoryURL.appendingPathComponent("\(Self.sanitized(chatSessionId)).json")
  }

  /// Session ids are UUID-shaped, but never trust an id as a path component.
  static func sanitized(_ id: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let cleaned = String(id.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    return cleaned.isEmpty ? "_" : cleaned
  }
}
