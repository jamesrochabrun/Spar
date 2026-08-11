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
  private let invocationStore: any MCPAppInvocationStoring
  private let grantStore: any MCPAppGrantStoring
  private let transcriptReader: any MCPAppInvocationTranscriptReading
  private var toolTemplatesByServer: [MCPAppServerCacheKey: [String: MCPAppToolTemplate]] = [:]
  private var resolvedServerKeys: Set<MCPAppServerCacheKey> = []
  private var appShellsByKey: [String: AgentHubMCPUIResource] = [:]
  private var grantedNetworkKeys: Set<String> = []
  private var resolutionTask: Task<Void, Never>?
  /// Chat session id each context persists under, bound once the id is known.
  private var chatSessionIdByContext: [String: String] = [:]
  /// Chained per-context persist tasks so writes land in capture order.
  private var persistTasksByContext: [String: Task<Void, Never>] = [:]
  /// Latest checkpoint payload the rendered app saved, by checkpoint id. The
  /// app's `save_checkpoint` bridge calls carry the user's full edited canvas.
  private var checkpointDataById: [String: String] = [:]
  /// Which context each checkpoint belongs to, so it persists with its session.
  private var contextKeyByCheckpointId: [String: String] = [:]

  public init(
    discoveryService: (any MCPAppDiscoveryServiceProtocol)? = nil,
    invocationStore: (any MCPAppInvocationStoring)? = nil,
    grantStore: (any MCPAppGrantStoring)? = nil,
    transcriptReader: (any MCPAppInvocationTranscriptReading)? = nil
  ) {
    self.discoveryService = discoveryService ?? MCPAppDiscoveryService.shared
    self.invocationStore = invocationStore ?? FileMCPAppInvocationStore()
    self.transcriptReader = transcriptReader ?? FileMCPAppInvocationTranscriptReader()
    let resolvedGrantStore = grantStore ?? FileMCPAppGrantStore()
    self.grantStore = resolvedGrantStore
    let grants = resolvedGrantStore.load()
    grantedNetworkKeys = grants.networkGrantKeys
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

    var invocations = invocationsByContext[contextKey] ?? []
    if let existingIndex = invocations.firstIndex(where: { $0.id == toolUseId }),
       invocations[existingIndex].arguments != nil {
      // A re-capture of a known tool_use id is the provider replaying the
      // session history on resume — new calls always mint fresh ids. Keep the
      // existing invocation: its arguments may carry the user's canvas edits
      // (folded in from a checkpoint save), which the replayed original would
      // silently revert.
      mcpLog.notice("recordToolUse replay-skip id=\(toolUseId, privacy: .public) tool=\(parsed.tool, privacy: .public)")
      scheduleResolution(provider: provider, projectPath: projectPath, contextKey: contextKey)
      return
    }

    let invocation = MCPAppInvocation(
      id: toolUseId,
      serverName: parsed.server,
      toolName: parsed.tool,
      arguments: arguments,
      result: nil
    )

    invocations.removeAll { $0.id == toolUseId }
    invocations.append(invocation)
    invocationsByContext[contextKey] = invocations
    persistInvocations(for: contextKey)

    scheduleResolution(provider: provider, projectPath: projectPath, contextKey: contextKey)
  }

  public func recordToolResult(contextKey: String, toolUseId: String, resultJSON: String?) {
    guard var invocations = invocationsByContext[contextKey],
          let index = invocations.firstIndex(where: { $0.id == toolUseId }) else {
      mcpLog.notice("recordToolResult unmatched id=\(toolUseId, privacy: .public)")
      return
    }

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
    persistInvocations(for: contextKey)
  }

  public func clearContext(_ contextKey: String) {
    invocationsByContext.removeValue(forKey: contextKey)
    chatSessionIdByContext.removeValue(forKey: contextKey)
    persistTasksByContext.removeValue(forKey: contextKey)
    for (id, owner) in contextKeyByCheckpointId where owner == contextKey {
      contextKeyByCheckpointId.removeValue(forKey: id)
      checkpointDataById.removeValue(forKey: id)
    }
  }

  // MARK: - Per-session persistence

  /// Binds a context to its chat session id so captures persist under it.
  /// New sessions get their id only after the first turn, so anything already
  /// captured in memory is flushed to the store on bind.
  public func bindChatSession(_ chatSessionId: String, contextKey: String) {
    guard !chatSessionId.isEmpty else { return }
    let previous = chatSessionIdByContext[contextKey]
    chatSessionIdByContext[contextKey] = chatSessionId
    if previous != chatSessionId, invocationsByContext[contextKey]?.isEmpty == false {
      persistInvocations(for: contextKey)
    }
  }

  /// Rehydrates a reopened session's whiteboard: loads the persisted
  /// invocations and checkpoints (unless live capture already populated the
  /// context) and resolves their app shells so the surface can render
  /// immediately.
  public func restoreChatSession(
    _ chatSessionId: String,
    contextKey: String,
    provider: SessionProviderKind,
    projectPath: String
  ) async {
    bindChatSession(chatSessionId, contextKey: contextKey)

    let stored = await invocationStore.loadState(chatSessionId: chatSessionId)
    let transcriptInvocations = await transcriptReader.invocations(
      provider: provider,
      projectPath: projectPath,
      chatSessionId: chatSessionId
    )
    // Checkpoints merge regardless of live capture: `read_checkpoint` callbacks
    // can reference checkpoints from earlier runs of the same session.
    for (id, data) in stored.checkpointDataById where checkpointDataById[id] == nil {
      checkpointDataById[id] = data
      contextKeyByCheckpointId[id] = contextKey
    }

    // Local state wins for arguments because save_checkpoint folds the user's
    // edited elements into them. The provider transcript fills missing results
    // (especially create_view's checkpoint id) and appends invocations not yet
    // seen by the live SDK callbacks.
    let localInvocations = invocationsByContext[contextKey]?.isEmpty == false
      ? invocationsByContext[contextKey] ?? []
      : stored.invocations
    let merged = Self.mergeInvocations(
      local: localInvocations,
      transcript: transcriptInvocations
    )
    guard !merged.isEmpty else { return }

    mcpLog.notice(
      "restored session=\(chatSessionId, privacy: .public) local=\(localInvocations.count) transcript=\(transcriptInvocations.count) merged=\(merged.count)"
    )
    invocationsByContext[contextKey] = merged
    persistInvocations(for: contextKey)
    await ensureRenderItems(provider: provider, projectPath: projectPath, contextKey: contextKey)
  }

  /// Merges the durable local whiteboard state with the provider transcript.
  /// Local arguments are authoritative because they may contain user edits;
  /// transcript results are authoritative when local live capture missed them.
  static func mergeInvocations(
    local: [MCPAppInvocation],
    transcript: [MCPAppInvocation]
  ) -> [MCPAppInvocation] {
    var merged = local
    for transcriptInvocation in transcript {
      guard let index = merged.firstIndex(where: { $0.id == transcriptInvocation.id }) else {
        merged.append(transcriptInvocation)
        continue
      }
      let localInvocation = merged[index]
      merged[index] = MCPAppInvocation(
        id: localInvocation.id,
        serverName: localInvocation.serverName,
        toolName: localInvocation.toolName,
        arguments: localInvocation.arguments ?? transcriptInvocation.arguments,
        result: localInvocation.result ?? transcriptInvocation.result
      )
    }
    return merged
  }

  /// Drops the persisted whiteboard state of a deleted session.
  public func deleteStoredInvocations(chatSessionId: String) async {
    for (contextKey, sessionId) in chatSessionIdByContext where sessionId == chatSessionId {
      chatSessionIdByContext.removeValue(forKey: contextKey)
      persistTasksByContext.removeValue(forKey: contextKey)
      for (id, owner) in contextKeyByCheckpointId where owner == contextKey {
        contextKeyByCheckpointId.removeValue(forKey: id)
        checkpointDataById.removeValue(forKey: id)
      }
    }
    await invocationStore.deleteState(chatSessionId: chatSessionId)
  }

  /// Awaits all in-flight persistence writes (used by tests and shutdown).
  public func flushPersistence() async {
    for task in persistTasksByContext.values {
      await task.value
    }
  }

  private func persistInvocations(for contextKey: String) {
    guard let chatSessionId = chatSessionIdByContext[contextKey] else {
      mcpLog.notice("persist skipped — context has no bound chat session (invocations=\(self.invocationsByContext[contextKey]?.count ?? 0))")
      return
    }
    let snapshot = StoredWhiteboardSessionState(
      invocations: invocationsByContext[contextKey] ?? [],
      checkpointDataById: checkpointDataById.filter {
        contextKeyByCheckpointId[$0.key] == contextKey
      }
    )
    let previous = persistTasksByContext[contextKey]
    persistTasksByContext[contextKey] = Task { [invocationStore] in
      await previous?.value
      await invocationStore.saveState(snapshot, chatSessionId: chatSessionId)
    }
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
  nonisolated static func parseMCPToolName(_ toolName: String) -> (server: String, tool: String)? {
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
    await flushPersistence()
    await discoveryService.shutdown()
  }

  // MARK: - MCPAppHostBridging

  public func callMCPAppTool(
    resource: MCPAppResource,
    name: String,
    arguments: AgentHubMCPUIJSONValue?
  ) async throws -> AgentHubMCPUIJSONValue {
    // The app saves the user's edited canvas through this bridge. Capture it
    // before forwarding so edits survive locally even when the remote server
    // rejects or later forgets the checkpoint.
    if name == "save_checkpoint",
       let id = arguments?["id"]?.stringValue,
       let data = arguments?["data"]?.stringValue {
      recordCheckpointSave(id: id, data: data)
    }

    // Serve checkpoint reads from the local capture: every save flowed through
    // here, so it is at least as fresh as the server's copy — and still there
    // after a relaunch when the remote server's checkpoint is gone.
    if name == "read_checkpoint",
       let id = arguments?["id"]?.stringValue,
       let cached = checkpointDataById[id] {
      return .object([
        "content": .array([
          .object(["type": .string("text"), "text": .string(cached)])
        ])
      ])
    }

    return try await discoveryService.callTool(
      provider: resource.provider,
      projectPath: resource.projectPath,
      serverName: resource.serverName,
      name: name,
      arguments: arguments
    )
  }

  /// Caches a saved checkpoint and folds its edited elements back into the
  /// invocation whose result issued that checkpoint id, so every future replay
  /// of the invocation — same run or after relaunch — draws the edited state.
  /// The live app is not disturbed: `tool-input` redelivery is identity-keyed.
  private func recordCheckpointSave(id: String, data: String) {
    mcpLog.notice("checkpoint save captured id=\(id, privacy: .public) bytes=\(data.count)")
    checkpointDataById[id] = data

    // Guard loose substring matching below against degenerate ids.
    guard id.count >= 8 else { return }
    for (contextKey, invocations) in invocationsByContext {
      guard let index = invocations.lastIndex(where: {
        Self.resultMentionsCheckpoint($0.result, id: id)
      }) else { continue }

      contextKeyByCheckpointId[id] = contextKey
      let existing = invocations[index]
      if let rewritten = Self.arguments(existing.arguments, replacingElementsWith: data) {
        var updated = invocations
        updated[index] = MCPAppInvocation(
          id: existing.id,
          serverName: existing.serverName,
          toolName: existing.toolName,
          arguments: rewritten,
          result: existing.result
        )
        invocationsByContext[contextKey] = updated
      }
      persistInvocations(for: contextKey)
      return
    }
    mcpLog.notice("checkpoint save matched no invocation id=\(id, privacy: .public) — cached in-memory only")
  }

  /// Whether a tool result references a checkpoint id (Claude stores the result
  /// as a JSON string, Codex as structured content — a serialized substring
  /// check covers both shapes).
  static func resultMentionsCheckpoint(_ result: AgentHubMCPUIJSONValue?, id: String) -> Bool {
    guard let result,
          let data = try? JSONEncoder().encode(result),
          let text = String(data: data, encoding: .utf8) else { return false }
    return text.contains(id)
  }

  /// Rebuilds tool arguments with `elements` replaced by the checkpoint's
  /// edited elements (checkpoint data is `{"elements":[...]}`).
  static func arguments(
    _ arguments: AgentHubMCPUIJSONValue?,
    replacingElementsWith checkpointData: String
  ) -> AgentHubMCPUIJSONValue? {
    guard let data = checkpointData.data(using: .utf8),
          let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let elements = parsed["elements"] as? [Any],
          let elementsData = try? JSONSerialization.data(withJSONObject: elements),
          let elementsJSON = String(data: elementsData, encoding: .utf8) else {
      return nil
    }
    var object: [String: AgentHubMCPUIJSONValue]
    if case .object(let existing)? = arguments {
      object = existing
    } else {
      object = [:]
    }
    object["elements"] = .string(elementsJSON)
    return .object(object)
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

  /// Durable network grants, keyed by app identity (server + sorted host set)
  /// so a new app, or one whose declared domains changed, still prompts.
  /// Loaded from disk at init and saved on grant, so an approved app renders
  /// straight to canvas after a relaunch instead of re-showing the banner.
  public func isMCPAppNetworkGranted(serverName: String, hosts: [String]) -> Bool {
    guard !hosts.isEmpty else { return false }
    return grantedNetworkKeys.contains(networkGrantKey(serverName: serverName, hosts: hosts))
  }

  public func grantMCPAppNetwork(serverName: String, hosts: [String]) {
    guard !hosts.isEmpty else { return }
    grantedNetworkKeys.insert(networkGrantKey(serverName: serverName, hosts: hosts))
    persistGrants()
  }

  // MARK: - Private helpers

  private func persistGrants() {
    grantStore.save(MCPAppGrantRecord(networkGrantKeys: grantedNetworkKeys))
  }

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
