//
//  MCPAppSessionService.swift
//  CodingBuddyChat
//
//  Port of AgentHub's MCP-app resolution block (CLISessionsViewModel): captures
//  in-process `mcp__<server>__<tool>` invocations, lazily resolves each used
//  server's tool->app templates (`tools/list` + `_meta.ui.resourceUri`) and app
//  shells (`resources/read`), and serves renderable items to the whiteboard
//  surface. Also the panel's host bridge and the per-launch network-grant set.
//

import BuddyMCPApps
import BuddyMCPUI
import Foundation
import Observation
import os

private let mcpLog = Logger(subsystem: "com.codingbuddy.mcp", category: "MCPAppSessionService")

@Observable @MainActor
public final class MCPAppSessionService: MCPAppHostBridging {

  struct MCPAppToolTemplate: Sendable, Equatable {
    let resourceUri: String
    let title: String?
  }

  /// Captured invocations per chat context key (one per ChatViewModel).
  public private(set) var invocationsByContext: [String: [MCPAppInvocation]] = [:]
  /// Bumped when resolution lands so the whiteboard re-derives its items.
  public private(set) var resolutionGeneration = 0
  /// Latest `ui/update-model-context` text per app resource — the app's own
  /// summary of what the user changed in it (e.g. Excalidraw canvas edits).
  /// Woven into the hidden context of the next outgoing message.
  public private(set) var modelContextTextByResourceID: [String: String] = [:]

  private let discoveryService: any MCPAppDiscoveryServiceProtocol
  private var toolTemplatesByServer: [MCPAppServerCacheKey: [String: MCPAppToolTemplate]] = [:]
  private var resolvedServerKeys: Set<MCPAppServerCacheKey> = []
  private var appShellsByKey: [String: AgentHubMCPUIResource] = [:]
  private var grantedNetworkKeys: Set<String> = []
  private var resolutionTask: Task<Void, Never>?

  public init(discoveryService: (any MCPAppDiscoveryServiceProtocol)? = nil) {
    self.discoveryService = discoveryService ?? MCPAppDiscoveryService.shared
  }

  // MARK: - Capture (fed from ChatViewModel's MCP hooks)

  public func recordToolUse(
    contextKey: String,
    provider: SessionProviderKind,
    projectPath: String,
    toolUseId: String,
    toolName: String,
    argumentsJSON: String?
  ) {
    guard let parsed = Self.parseMCPToolName(toolName) else { return }

    let arguments = argumentsJSON
      .flatMap { $0.data(using: .utf8) }
      .flatMap { try? JSONSerialization.jsonObject(with: $0) }
      .map { AgentHubMCPUIJSONValue(any: $0) }

    let invocation = MCPAppInvocation(
      id: toolUseId,
      serverName: parsed.server,
      toolName: parsed.tool,
      arguments: arguments,
      result: nil
    )

    var invocations = invocationsByContext[contextKey] ?? []
    invocations.removeAll { $0.id == toolUseId }
    invocations.append(invocation)
    invocationsByContext[contextKey] = invocations

    scheduleResolution(provider: provider, projectPath: projectPath, contextKey: contextKey)
  }

  public func recordToolResult(contextKey: String, toolUseId: String, resultJSON: String?) {
    guard var invocations = invocationsByContext[contextKey],
          let index = invocations.firstIndex(where: { $0.id == toolUseId }) else { return }

    let result = resultJSON.map(Self.parseToolResult)

    let existing = invocations[index]
    invocations[index] = MCPAppInvocation(
      id: existing.id,
      serverName: existing.serverName,
      toolName: existing.toolName,
      arguments: existing.arguments,
      result: result
    )
    invocationsByContext[contextKey] = invocations
  }

  public func clearContext(_ contextKey: String) {
    invocationsByContext.removeValue(forKey: contextKey)
  }

  /// Parses a captured tool result: JSON when it is JSON (Codex's `Ok` error
  /// envelope unwrapped), otherwise the raw text as a string value.
  static func parseToolResult(_ raw: String) -> AgentHubMCPUIJSONValue {
    guard let data = raw.data(using: .utf8),
          let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
      return .string(raw)
    }

    var value = AgentHubMCPUIJSONValue(any: parsed)
    if case .object(let object) = value, object.count == 1, let ok = object["Ok"] {
      value = ok
    }
    return value
  }

  /// Splits a provider-qualified MCP tool name into server + short tool name.
  /// Claude uses `mcp__<server>__<tool>`; Codex's item stream flattens the
  /// invocation to `<server>__<tool>` or `<server>.<tool>`.
  static func parseMCPToolName(_ toolName: String) -> (server: String, tool: String)? {
    if toolName.hasPrefix("mcp__") {
      let parts = toolName.split(separator: "__", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
      guard parts.count == 3, !parts[1].isEmpty, !parts[2].isEmpty else { return nil }
      return (parts[1], parts[2])
    }

    if toolName.contains("__") {
      let parts = toolName.split(separator: "__", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
      guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
      return (parts[0], parts[1])
    }

    if let dot = toolName.firstIndex(of: ".") {
      let server = String(toolName[..<dot])
      let tool = String(toolName[toolName.index(after: dot)...])
      guard !server.isEmpty, !tool.isEmpty else { return nil }
      return (server, tool)
    }

    return nil
  }

  // MARK: - Lazy resolution

  private func scheduleResolution(provider: SessionProviderKind, projectPath: String, contextKey: String) {
    guard resolutionTask == nil else { return }
    resolutionTask = Task { [weak self] in
      await self?.ensureRenderItems(provider: provider, projectPath: projectPath, contextKey: contextKey)
      self?.resolutionTask = nil
    }
  }

  /// For each server actually used, fetch `tools/list` once to learn which
  /// tools declare a `ui://` app, then read each needed app shell once.
  public func ensureRenderItems(
    provider: SessionProviderKind,
    projectPath: String,
    contextKey: String
  ) async {
    let invocations = invocationsByContext[contextKey] ?? []
    guard !invocations.isEmpty else { return }
    let normalizedProjectPath = MCPAppDiscoveryService.normalize(projectPath)

    for serverName in Set(invocations.map(\.serverName)) {
      let serverKey = MCPAppServerCacheKey(
        provider: provider,
        projectPath: normalizedProjectPath,
        serverName: serverName
      )
      guard !resolvedServerKeys.contains(serverKey) else { continue }
      do {
        let toolsResult = try await discoveryService.listTools(
          provider: provider,
          projectPath: normalizedProjectPath,
          serverName: serverName
        )
        toolTemplatesByServer[serverKey] = Self.parseToolTemplates(from: toolsResult)
        resolvedServerKeys.insert(serverKey)
      } catch {
        mcpLog.error("tools/list failed server=\(serverName, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        // Leave unresolved so a later invocation retries.
      }
    }

    for invocation in invocations {
      let serverKey = MCPAppServerCacheKey(
        provider: provider,
        projectPath: normalizedProjectPath,
        serverName: invocation.serverName
      )
      guard let template = toolTemplatesByServer[serverKey]?[invocation.toolName] else { continue }
      let shellKey = shellCacheKey(
        provider: provider,
        projectPath: normalizedProjectPath,
        serverName: invocation.serverName,
        uri: template.resourceUri
      )
      guard appShellsByKey[shellKey] == nil else { continue }
      do {
        let readResult = try await discoveryService.readResource(
          provider: provider,
          projectPath: normalizedProjectPath,
          serverName: invocation.serverName,
          uri: template.resourceUri
        )
        if let shell = Self.parseAppShellResource(from: readResult, uri: template.resourceUri) {
          appShellsByKey[shellKey] = shell
        }
      } catch {
        mcpLog.error("shell read failed uri=\(template.resourceUri, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      }
    }

    resolutionGeneration += 1
  }

  /// Renderable host apps for a context: the resolved app shell paired with
  /// the agent invocation whose input/result seed it.
  public func renderItems(
    provider: SessionProviderKind,
    projectPath: String,
    contextKey: String
  ) -> [MCPAppRenderItem] {
    _ = resolutionGeneration
    let invocations = invocationsByContext[contextKey] ?? []
    guard !invocations.isEmpty else { return [] }
    let normalizedProjectPath = MCPAppDiscoveryService.normalize(projectPath)

    return invocations.compactMap { invocation in
      let serverKey = MCPAppServerCacheKey(
        provider: provider,
        projectPath: normalizedProjectPath,
        serverName: invocation.serverName
      )
      guard let template = toolTemplatesByServer[serverKey]?[invocation.toolName] else { return nil }
      let shellKey = shellCacheKey(
        provider: provider,
        projectPath: normalizedProjectPath,
        serverName: invocation.serverName,
        uri: template.resourceUri
      )
      guard let shell = appShellsByKey[shellKey] else { return nil }
      let title = Self.deriveTitle(from: invocation)
        ?? template.title
        ?? shell.metadata.title
        ?? invocation.toolName
      let resource = MCPAppResource(
        provider: provider,
        projectPath: normalizedProjectPath,
        serverName: invocation.serverName,
        title: title,
        source: .liveDiscovery,
        resource: shell
      )
      return MCPAppRenderItem(resource: resource, invocation: invocation)
    }
  }

  public func shutdown() async {
    await discoveryService.shutdown()
  }

  // MARK: - MCPAppHostBridging

  public func callMCPAppTool(
    resource: MCPAppResource,
    name: String,
    arguments: AgentHubMCPUIJSONValue?
  ) async throws -> AgentHubMCPUIJSONValue {
    try await discoveryService.callTool(
      provider: resource.provider,
      projectPath: resource.projectPath,
      serverName: resource.serverName,
      name: name,
      arguments: arguments
    )
  }

  public func readMCPAppResource(
    resource: MCPAppResource,
    uri: String
  ) async throws -> AgentHubMCPUIJSONValue {
    try await discoveryService.readResource(
      provider: resource.provider,
      projectPath: resource.projectPath,
      serverName: resource.serverName,
      uri: uri
    )
  }

  public func listMCPAppResources(
    resource: MCPAppResource
  ) async throws -> AgentHubMCPUIJSONValue {
    try await discoveryService.listResources(
      provider: resource.provider,
      projectPath: resource.projectPath,
      serverName: resource.serverName
    )
  }

  public func noteMCPAppModelContext(resource: MCPAppResource, params: AgentHubMCPUIJSONValue?) {
    guard let text = Self.modelContextText(from: params), !text.isEmpty else { return }
    modelContextTextByResourceID[resource.id] = text
  }

  /// Consumes (returns and clears) the stored model-context texts for the given
  /// render items, deduplicating shared resources. Cleared on read so the same
  /// edit summary is not re-sent on every subsequent message.
  public func consumeModelContextTexts(for items: [MCPAppRenderItem]) -> [String] {
    var seen = Set<String>()
    var texts: [String] = []
    for item in items {
      let resourceID = item.resource.id
      guard seen.insert(resourceID).inserted,
            let text = modelContextTextByResourceID.removeValue(forKey: resourceID) else {
        continue
      }
      texts.append(text)
    }
    return texts
  }

  /// Extracts the plain text of a `ui/update-model-context` payload
  /// (`{content:[{type:"text",text}]}`, with a bare `{text}` fallback).
  static func modelContextText(from params: AgentHubMCPUIJSONValue?) -> String? {
    guard let params else { return nil }
    if let blocks = params["content"]?.arrayValue {
      let texts = blocks.compactMap { $0["text"]?.stringValue }
      if !texts.isEmpty {
        return texts.joined(separator: "\n")
      }
    }
    return params["text"]?.stringValue
  }

  /// Per-launch network grants, keyed by app identity (server + sorted host
  /// set) so a new app, or one whose declared domains changed, still prompts.
  public func isMCPAppNetworkGranted(serverName: String, hosts: [String]) -> Bool {
    guard !hosts.isEmpty else { return false }
    return grantedNetworkKeys.contains(networkGrantKey(serverName: serverName, hosts: hosts))
  }

  public func grantMCPAppNetwork(serverName: String, hosts: [String]) {
    guard !hosts.isEmpty else { return }
    grantedNetworkKeys.insert(networkGrantKey(serverName: serverName, hosts: hosts))
  }

  // MARK: - Private helpers

  private func networkGrantKey(serverName: String, hosts: [String]) -> String {
    ([serverName] + hosts.sorted()).joined(separator: "|")
  }

  private func shellCacheKey(
    provider: SessionProviderKind,
    projectPath: String,
    serverName: String,
    uri: String
  ) -> String {
    [provider.rawValue, projectPath, serverName, uri].joined(separator: "|")
  }

  static func parseToolTemplates(from toolsResult: AgentHubMCPUIJSONValue) -> [String: MCPAppToolTemplate] {
    guard let tools = toolsResult["tools"]?.arrayValue else { return [:] }
    var templates: [String: MCPAppToolTemplate] = [:]
    for tool in tools {
      guard let name = tool["name"]?.stringValue else { continue }
      let meta = tool["_meta"]
      let uri = meta?["ui"]?["resourceUri"]?.stringValue
        ?? meta?["ui/resourceUri"]?.stringValue
      guard let uri else { continue }
      templates[name] = MCPAppToolTemplate(resourceUri: uri, title: tool["title"]?.stringValue)
    }
    return templates
  }

  static func parseAppShellResource(
    from readResult: AgentHubMCPUIJSONValue,
    uri: String
  ) -> AgentHubMCPUIResource? {
    guard let contents = readResult["contents"]?.arrayValue else { return nil }
    for content in contents {
      guard let text = content["text"]?.stringValue else { continue }
      let contentURI = content["uri"]?.stringValue ?? uri
      let mimeType = content["mimeType"]?.stringValue
        ?? content["mime_type"]?.stringValue
        ?? AgentHubMCPUIResource.htmlAppMimeType
      let metadata = MCPAppResourceExtractor.metadata(from: content.anyValue)
      return AgentHubMCPUIResource(
        uri: contentURI,
        mimeType: mimeType,
        text: text,
        metadata: metadata
      )
    }
    return nil
  }

  /// Derives a human label for an app invocation from its drawing content (the
  /// first text element, then any shape label).
  static func deriveTitle(from invocation: MCPAppInvocation) -> String? {
    guard let elementsValue = invocation.arguments?["elements"] else { return nil }
    let elements: [AgentHubMCPUIJSONValue]
    switch elementsValue {
    case .array(let array):
      elements = array
    case .string(let json):
      guard let data = json.data(using: .utf8),
            let parsed = try? JSONDecoder().decode([AgentHubMCPUIJSONValue].self, from: data) else {
        return nil
      }
      elements = parsed
    default:
      return nil
    }

    func cleaned(_ text: String?) -> String? {
      guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
      }
      return String(trimmed.prefix(48))
    }

    if let text = elements.lazy.compactMap({ element -> String? in
      element["type"]?.stringValue == "text" ? cleaned(element["text"]?.stringValue) : nil
    }).first {
      return text
    }
    return elements.lazy.compactMap { cleaned($0["label"]?["text"]?.stringValue) }.first
  }
}
