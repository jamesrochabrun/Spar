//
//  MCPAppGrantStore.swift
//  CodingBuddyChat
//
//  Durable network (CSP) grants for MCP apps. Action consent remains scoped to
//  the current panel session, matching AgentHub's host permission model.
//

import Foundation
import ClaudeCodeCore

public struct MCPAppGrantRecord: Codable, Sendable, Equatable {
  public var networkGrantKeys: Set<String>

  public init(networkGrantKeys: Set<String> = []) {
    self.networkGrantKeys = networkGrantKeys
  }
}

public protocol MCPAppGrantStoring: Sendable {
  func load() -> MCPAppGrantRecord
  func save(_ record: MCPAppGrantRecord)
}

/// Single-file JSON store in the app's Application Support directory. Grants
/// are tiny and granted rarely, so loads/saves are synchronous.
public struct FileMCPAppGrantStore: MCPAppGrantStoring {

  private let fileURL: URL

  public init(fileURL: URL? = nil) {
    self.fileURL = fileURL ?? AppStorageLocations.applicationSupportDirectory()
      .appendingPathComponent("MCPAppGrants.json")
  }

  public func load() -> MCPAppGrantRecord {
    guard let data = try? Data(contentsOf: fileURL),
          let record = try? JSONDecoder().decode(MCPAppGrantRecord.self, from: data) else {
      return MCPAppGrantRecord()
    }
    return record
  }

  public func save(_ record: MCPAppGrantRecord) {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(record)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      // Best-effort: a failed save only means a re-prompt next launch.
    }
  }
}
