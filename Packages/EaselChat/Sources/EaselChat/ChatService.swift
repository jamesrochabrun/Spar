//
//  ChatService.swift
//  EaselChat
//

import AgentHarness
import AgentProviderMLX
import AgentProviderOllama
import AgentProviderOpenAI
import ClaudeCodeCore
import ClaudeCodeSDK
import EaselKit
import Foundation
import OSLog

private let chatLog = Logger(subsystem: "com.codingbuddy.chat", category: "ChatService")

private struct ChatSessionContext {
  let viewModel: ChatViewModel
  let deps: DependencyContainer
  let reference: ChatViewModelReference
}

private enum ChatServiceError: LocalizedError {
  case missingGlobalPreferences

  var errorDescription: String? {
    switch self {
    case .missingGlobalPreferences:
      return "Chat service preferences are not initialized."
    }
  }
}

private final class ChatViewModelReference {
  weak var viewModel: ChatViewModel?
}

@Observable @MainActor
public final class ChatService: ChatServiceProtocol {

  // MARK: - Public State

  public private(set) var chatViewModel: ChatViewModel?
  public private(set) var deps: DependencyContainer?
  public private(set) var globalPreferences: GlobalPreferencesStorage?
  public private(set) var isInitialized = false
  public private(set) var initError: Error?
  public private(set) var currentSessionId: String?
  public private(set) var currentWorkingDirectory: String?
  public private(set) var currentWorkspaceUsageSummary: SessionUsageSummary = .zero
  public private(set) var sessionStorage: SessionStorageProtocol
  public var mcpToolsDiscoveryService: MCPToolsDiscoveryService { mcpToolsDiscovery }

  /// On-device MLX model management, shared by the chat runtime and the
  /// settings download UI. One instance app-wide — the loaded model is the
  /// process's GPU tenant.
  public let onDeviceModelManager = MLXModelManager()
  @ObservationIgnored private lazy var onDeviceModelRuntime = MLXModelRuntime(manager: onDeviceModelManager)

  /// A model catalog for the settings picker that knows about on-device MLX
  /// models (dispatches `.mlxLocal` profiles to the installed-model list).
  public var apiModelCatalog: any APIModelCatalogProviding {
    APIModelCatalog(clientFactory: apiModelClientFactory)
  }

  /// Model-client factory for the Local / API provider: routes on-device
  /// profiles to MLX and everything else to the HTTP adapters.
  var apiModelClientFactory: @Sendable (EndpointProfile, String?) -> any AgentModelClient {
    let manager = onDeviceModelManager
    let runtime = onDeviceModelRuntime
    return { profile, apiKey in
      switch profile.kind {
      case .mlxLocal:
        return MLXModelClient(profile: profile, runtime: runtime, manager: manager)
      case .ollamaNative:
        return OllamaNativeModelClient(profile: profile)
      case .openAICompatible:
        return OpenAICompatibleModelClient(profile: profile, apiKey: apiKey)
      }
    }
  }

  /// Called when a session changes (created or switched), so the sidebar can refresh
  public var onSessionChanged: (() -> Void)?

  private var isInitializing = false
  private let persistentPreferencesManager: PersistentPreferencesManager
  private let mcpToolsDiscovery: MCPToolsDiscoveryService
  private let logger: ClaudeCodeLogger
  private var currentWorkspaceUsageTask: Task<Void, Never>?
  private var sessionContextsById: [String: ChatSessionContext] = [:]
  private var pendingSessionContextsByViewModelId: [ObjectIdentifier: ChatSessionContext] = [:]
  private var sessionIdByViewModelId: [ObjectIdentifier: String] = [:]
  private var activeSessionContext: ChatSessionContext?

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol = SimplifiedClaudeCodeSQLiteStorage(),
    persistentPreferencesManager: PersistentPreferencesManager? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    logger: ClaudeCodeLogger = ClaudeCodeLogger()
  ) {
    self.sessionStorage = sessionStorage
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.logger = logger
    self.persistentPreferencesManager = persistentPreferencesManager ?? PersistentPreferencesManager(logger: logger)
  }

  // MARK: - Initialization

  public func initialize() async {
    guard !isInitialized else { return }
    if isInitializing {
      while isInitializing && !isInitialized {
        try? await Task.sleep(for: .milliseconds(50))
      }
      return
    }

    isInitializing = true
    defer { isInitializing = false }

    do {
      let globalPrefs = GlobalPreferencesStorage(
        persistentManager: persistentPreferencesManager,
        logger: logger
      )
      let context = try makeSessionContext(globalPreferences: globalPrefs)

      setCurrentWorkingDirectory(context.viewModel.projectPath)

      self.chatViewModel = context.viewModel
      self.deps = context.deps
      self.activeSessionContext = context
      self.globalPreferences = globalPrefs
      self.isInitialized = true
    } catch {
      self.initError = error
    }
  }

  public func retry() {
    initError = nil
    isInitialized = false
    sessionContextsById.removeAll()
    pendingSessionContextsByViewModelId.removeAll()
    sessionIdByViewModelId.removeAll()
    activeSessionContext = nil
    Task { await initialize() }
  }

  // MARK: - ChatServiceProtocol

  public func sendMessage(_ text: String, context: String? = nil, hiddenContext: String? = nil) {
    sendMessageToViewModel(text, context: context, hiddenContext: hiddenContext)
  }

  // MARK: - Session Management

  public func switchToSession(_ session: StoredSession) async {
    let initialized = await ensureInitialized()
    guard initialized else { return }

    // Save current session before switching
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }
    retainCurrentSessionContext()

    // Load fresh session data from storage, fall back to the passed object
    let sessionToLoad: StoredSession
    if let stored = try? await sessionStorage.getSession(id: session.id) {
      sessionToLoad = stored
    } else {
      sessionToLoad = session
    }

    let context: ChatSessionContext
    if let existingContext = sessionContextsById[sessionToLoad.id] {
      context = existingContext
    } else {
      do {
        context = try makeSessionContext(workingDirectory: sessionToLoad.workingDirectory)
      } catch {
        initError = error
        return
      }

      context.viewModel.injectSession(
        sessionId: sessionToLoad.id,
        messages: sessionToLoad.messages,
        workingDirectory: sessionToLoad.workingDirectory,
        provider: sessionToLoad.provider,
        usageSummary: sessionToLoad.usageSummary
      )
      sessionContextsById[sessionToLoad.id] = context
      sessionIdByViewModelId[ObjectIdentifier(context.viewModel)] = sessionToLoad.id
    }

    activateContext(context)

    setCurrentWorkingDirectory(normalized(context.viewModel.projectPath) ?? sessionToLoad.workingDirectory)
    setCurrentSessionId(sessionToLoad.id)
  }

  public func startNewSession(workingDirectory: String?) async {
    let initialized = await ensureInitialized()
    guard initialized else { return }

    // Save current session before starting new one
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }
    retainCurrentSessionContext()

    let context: ChatSessionContext
    do {
      context = try makeSessionContext(workingDirectory: workingDirectory)
    } catch {
      initError = error
      return
    }

    activateContext(context)
    pendingSessionContextsByViewModelId[ObjectIdentifier(context.viewModel)] = context

    // Set the working directory for the new chat
    setCurrentWorkingDirectory(normalized(workingDirectory) ?? context.viewModel.projectPath)

    setCurrentSessionId(nil)
    refreshCurrentWorkspaceUsage()
  }

  public func deleteSession(_ session: StoredSession) async {
    try? await sessionStorage.deleteSession(id: session.id)
    if let context = sessionContextsById.removeValue(forKey: session.id) {
      sessionIdByViewModelId.removeValue(forKey: ObjectIdentifier(context.viewModel))
      if activeSessionContext?.viewModel === context.viewModel {
        activeSessionContext = nil
      }
      if !isVisibleViewModel(context.viewModel) {
        context.viewModel.clearConversation()
      }
    }

    if currentSessionId == session.id {
      activeSessionContext = nil
      setCurrentSessionId(nil)
      chatViewModel?.clearConversation()
    }
    refreshCurrentWorkspaceUsage()
  }

  public func clearActiveWorkspace() {
    let retainedContexts = Array(sessionContextsById.values) + Array(pendingSessionContextsByViewModelId.values)
    for context in retainedContexts {
      if isVisibleViewModel(context.viewModel) { continue }
      context.viewModel.clearConversation()
    }
    sessionContextsById.removeAll()
    pendingSessionContextsByViewModelId.removeAll()
    sessionIdByViewModelId.removeAll()
    activeSessionContext = nil
    setCurrentSessionId(nil)
    chatViewModel?.clearConversation()
    chatViewModel?.setWorkingDirectory("")
    setCurrentWorkingDirectory(nil)
  }

  // MARK: - Private

  private func ensureInitialized() async -> Bool {
    if !isInitialized {
      await initialize()
    }

    return isInitialized
  }

  private func makeSessionContext(
    globalPreferences preferences: GlobalPreferencesStorage? = nil,
    workingDirectory: String? = nil
  ) throws -> ChatSessionContext {
    guard let preferences = preferences ?? globalPreferences else {
      throw ChatServiceError.missingGlobalPreferences
    }

    let container = DependencyContainer(
      globalPreferences: preferences,
      customSessionStorage: sessionStorage,
      mcpToolsDiscovery: mcpToolsDiscovery,
      logger: logger
    )

    var config = ChatConfiguration.makeDefault()
    config.command = preferences.claudeCommand

    if let workingDirectory = normalized(workingDirectory) {
      config.workingDirectory = workingDirectory
      container.settingsStorage.setProjectPath(workingDirectory)
    } else if let workingDirectory = normalized(config.workingDirectory) {
      container.settingsStorage.setProjectPath(workingDirectory)
    }

    let client = try ClaudeCodeClient(configuration: config)
    let reference = ChatViewModelReference()
    let viewModel = ChatViewModel(
      claudeClient: client,
      sessionStorage: sessionStorage,
      settingsStorage: container.settingsStorage,
      globalPreferences: preferences,
      customPermissionService: container.customPermissionService,
      mcpToolsDiscovery: mcpToolsDiscovery,
      logger: logger,
      systemPromptPrefix: EaselAgentInstructions.systemPromptPrefix,
      codexDeveloperInstructionsPrefix: EaselAgentInstructions.codexDeveloperInstructionsPrefix,
      apiInstructionsPrefix: EaselAgentInstructions.apiAgentInstructionsPrefix,
      apiModelClientFactory: apiModelClientFactory,
      shouldManageSessions: true,
      onSessionChange: { [weak self, weak reference] newSessionId in
        Task { @MainActor in
          guard let viewModel = reference?.viewModel else { return }
          self?.handleSessionChange(newSessionId, from: viewModel)
        }
      },
      onSessionUsageChange: { [weak self, weak reference] _ in
        Task { @MainActor in
          guard let self else { return }
          if self.isVisibleViewModel(reference?.viewModel) {
            self.refreshCurrentWorkspaceUsage()
          }
          self.onSessionChanged?()
        }
      }
    )
    reference.viewModel = viewModel

    viewModel.runtimeHiddenContextProvider = { [weak self, weak viewModel] in
      self?.makeHiddenContext(for: viewModel, hiddenContext: nil)
    }

    return ChatSessionContext(viewModel: viewModel, deps: container, reference: reference)
  }

  private func retainCurrentSessionContext() {
    guard let chatViewModel,
          let context = activeSessionContext,
          context.viewModel === chatViewModel else { return }

    let viewModelId = ObjectIdentifier(chatViewModel)
    if let sessionId = currentSessionId ?? sessionIdByViewModelId[viewModelId] {
      sessionContextsById[sessionId] = context
      sessionIdByViewModelId[viewModelId] = sessionId
    } else if chatViewModel.isLoading || !chatViewModel.messages.isEmpty {
      pendingSessionContextsByViewModelId[viewModelId] = context
    }
  }

  private func context(for viewModel: ChatViewModel) -> ChatSessionContext? {
    let viewModelId = ObjectIdentifier(viewModel)
    if let sessionId = sessionIdByViewModelId[viewModelId],
       let context = sessionContextsById[sessionId] {
      return context
    }

    if let context = pendingSessionContextsByViewModelId[viewModelId] {
      return context
    }

    if chatViewModel === viewModel,
       let activeSessionContext,
       activeSessionContext.viewModel === viewModel {
      return activeSessionContext
    }

    return nil
  }

  private func activateContext(_ context: ChatSessionContext) {
    chatViewModel = context.viewModel
    deps = context.deps
    activeSessionContext = context
  }

  private func handleSessionChange(_ sessionId: String, from viewModel: ChatViewModel) {
    guard let context = context(for: viewModel) else { return }

    let viewModelId = ObjectIdentifier(viewModel)
    pendingSessionContextsByViewModelId.removeValue(forKey: viewModelId)
    sessionContextsById[sessionId] = context
    sessionIdByViewModelId[viewModelId] = sessionId

    guard isVisibleViewModel(viewModel) else {
      onSessionChanged?()
      return
    }

    setCurrentSessionId(sessionId)
    setCurrentWorkingDirectory(viewModel.projectPath)
    refreshCurrentWorkspaceUsage()
    onSessionChanged?()
  }

  private func isVisibleViewModel(_ viewModel: ChatViewModel?) -> Bool {
    guard let viewModel, let chatViewModel else { return false }
    return chatViewModel === viewModel
  }

  private func sendMessageToViewModel(_ text: String, context: String? = nil, hiddenContext: String? = nil) {
    guard let chatViewModel else { return }

    chatViewModel.sendMessage(text, context: context, hiddenContext: hiddenContext)
  }

  private func makeHiddenContext(
    for viewModel: ChatViewModel?,
    hiddenContext: String?
  ) -> String {
    let workingDirectory = normalized(viewModel?.projectPath) ?? currentWorkingDirectory

    return EaselAgentInstructions.appendingHiddenContext(
      hiddenContext,
      workingDirectory: workingDirectory
    )
  }

  private func setCurrentWorkingDirectory(_ path: String?) {
    let normalized = path?.trimmingCharacters(in: .whitespacesAndNewlines)
    currentWorkingDirectory = normalized?.isEmpty == false ? normalized : nil
    refreshCurrentWorkspaceUsage()
  }

  private func refreshCurrentWorkspaceUsage() {
    currentWorkspaceUsageTask?.cancel()

    guard let workingDirectory = currentWorkingDirectory else {
      currentWorkspaceUsageSummary = .zero
      return
    }

    currentWorkspaceUsageTask = Task { [sessionStorage] in
      let summary = (try? await sessionStorage.usageSummaryForWorkingDirectory(workingDirectory)) ?? .zero
      guard !Task.isCancelled else { return }

      await MainActor.run { [weak self] in
        guard self?.currentWorkingDirectory == workingDirectory else { return }
        self?.currentWorkspaceUsageSummary = summary
      }
    }
  }

  private func setCurrentSessionId(_ sessionId: String?) {
    currentSessionId = sessionId
  }

  private func normalized(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }
}
