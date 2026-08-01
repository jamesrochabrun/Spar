//
//  BuddyMCPAppsShims.swift
//  BuddyMCPApps
//
//  Local stand-ins for the two AgentHub symbols the ported files reference:
//  SessionProviderKind (copied enum) and AppLogger.mcp (local os.Logger).
//

import Foundation
import os

public enum SessionProviderKind: String, CaseIterable, Codable, Sendable {
  case claude = "Claude"
  case codex = "Codex"
}

enum AppLogger {
  static let mcp = Logger(subsystem: "com.codingbuddy.mcp", category: "MCPApps")
}
