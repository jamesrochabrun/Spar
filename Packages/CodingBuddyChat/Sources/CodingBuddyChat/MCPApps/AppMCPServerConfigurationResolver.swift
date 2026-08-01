//
//  AppMCPServerConfigurationResolver.swift
//  CodingBuddyChat
//
//  Config seam: the agent session (ClaudeCodeCore) passes its MCP config file
//  to the CLI, and this resolver reads the SAME file for the app-side MCP
//  connections — single source of truth. The path is resolved per call so a
//  settings change (custom mcpConfigPath) applies without restart.
//

import BuddyMCPApps
import Foundation

public struct AppMCPServerConfigurationResolver: MCPServerConfigurationResolverProtocol {

  private let configPathProvider: @Sendable () -> String

  /// Default path mirrors ClaudeCodeCore's MCPConfigurationManager.
  public static func defaultConfigPath() -> String {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config")
      .appendingPathComponent("claude")
      .appendingPathComponent("mcp-config.json")
      .path
  }

  public init(configPathProvider: @escaping @Sendable () -> String) {
    self.configPathProvider = configPathProvider
  }

  public func serverConfigurations(
    provider: SessionProviderKind,
    projectPath: String
  ) async -> [MCPServerConfiguration] {
    let path = configPathProvider()
    let resolver = DefaultMCPServerConfigurationResolver(claudeConfigPath: path)
    // The app's mcp-config.json uses the `mcpServers` top-level shape, which
    // the claude parser reads regardless of the provider that ran the session.
    return await resolver.serverConfigurations(provider: .claude, projectPath: projectPath)
      .map { config in
        MCPServerConfiguration(
          provider: provider,
          projectPath: config.projectPath,
          name: config.name,
          command: config.command,
          args: config.args,
          env: config.env,
          cwd: config.cwd,
          transport: config.transport
        )
      }
  }
}
