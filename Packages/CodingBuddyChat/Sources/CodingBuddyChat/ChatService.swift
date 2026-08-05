//
//  ChatService.swift
//  CodingBuddyChat
//

import AgentHarness
import AgentProviderMLX
import AgentProviderOllama
import AgentProviderOpenAI
import BuddyMCPApps
import BuddyMCPUI
import ClaudeCodeCore
import ClaudeCodeSDK
import CodingBuddyKit
import Foundation
import InterviewKit
import OSLog

private let chatLog = Logger(subsystem: "com.codingbuddy.chat", category: "ChatService")

struct ChatSessionContext {
  let viewModel: ChatViewModel
  let deps: DependencyContainer
  let reference: ChatViewModelReference
  let mode: SessionMode
  let specialization: InterviewSpecialization
  let mcpContextKey: String
}

enum ChatServiceError: LocalizedError {
  case missingGlobalPreferences

  var errorDescription: String? {
    switch self {
    case .missingGlobalPreferences:
      return "Chat service preferences are not initialized."
    }
  }
}

final class ChatViewModelReference {
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

  // MARK: - Interview services

  public let interviewStorage: any InterviewStorageProtocol
  public let interviewSession: InterviewSessionService
  public let questionBank: QuestionBankService
  public let skillStats: SkillStatsService
  public let sessionTimer = SessionTimer()
  public let mcpApps: MCPAppSessionService
  /// Interview preferences (specialization track). Read at session-context
  /// creation, so a settings change applies to the next session started.
  public let interviewSettings: BuddyInterviewSettings

  /// Mode of the currently visible session, driving surface availability.
  public var currentMode: SessionMode? { activeSessionContext?.mode }

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
  /// Called when an evaluation lands so the UI can auto-switch to the report surface.
  public var onEvaluationRecorded: ((RubricEvaluation) -> Void)?

  private var isInitializing = false
  private let persistentPreferencesManager: PersistentPreferencesManager
  private let mcpToolsDiscovery: MCPToolsDiscoveryService
  private let logger: ClaudeCodeLogger
  private var currentWorkspaceUsageTask: Task<Void, Never>?
  private var sessionContextsById: [String: ChatSessionContext] = [:]
  private var pendingSessionContextsByViewModelId: [ObjectIdentifier: ChatSessionContext] = [:]
  private var sessionIdByViewModelId: [ObjectIdentifier: String] = [:]
  private var activeSessionContext: ChatSessionContext?
  private var capturedAssistantMessageIds: Set<UUID> = []
  private var evaluationRepairAttempts = 0
  private let maxEvaluationRepairAttempts = 2

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol = SimplifiedClaudeCodeSQLiteStorage(),
    interviewStorage: (any InterviewStorageProtocol)? = nil,
    workspaceManager: (any InterviewWorkspaceManaging)? = nil,
    interviewSettings: BuddyInterviewSettings? = nil,
    persistentPreferencesManager: PersistentPreferencesManager? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    logger: ClaudeCodeLogger = ClaudeCodeLogger()
  ) {
    let resolvedInterviewStorage = interviewStorage ?? InterviewSQLiteStorage()
    self.sessionStorage = sessionStorage
    self.interviewStorage = resolvedInterviewStorage
    self.interviewSettings = interviewSettings ?? BuddyInterviewSettings()
    self.interviewSession = InterviewSessionService(
      storage: resolvedInterviewStorage,
      workspaceManager: workspaceManager ?? InterviewWorkspaceManager()
    )
    self.questionBank = QuestionBankService(storage: resolvedInterviewStorage)
    self.skillStats = SkillStatsService(storage: resolvedInterviewStorage)
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.logger = logger
    self.persistentPreferencesManager = persistentPreferencesManager ?? PersistentPreferencesManager(logger: logger)
    self.mcpApps = MCPAppSessionService(
      discoveryService: MCPAppDiscoveryService(
        resolver: AppMCPServerConfigurationResolver(configPathProvider: {
          AppMCPServerConfigurationResolver.defaultConfigPath()
        })
      )
    )

    sessionTimer.onExpiry = { [weak self] in
      Task { @MainActor [weak self] in
        await self?.handleTimerExpired()
      }
    }
    interviewSession.onEvaluationCompleted = { [weak self] evaluation in
      self?.sessionTimer.stop()
      self?.onEvaluationRecorded?(evaluation)
    }
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
      let context = try makeSessionContext(mode: .practice, globalPreferences: globalPrefs)

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

  // MARK: - Interview session lifecycle

  public struct NewSessionRequest {
    public var mode: SessionMode
    public var question: Question?
    public var topicIds: [String]
    public var difficulty: Difficulty?
    public var durationSeconds: Int?
    public var hintBudget: Int
    public var provider: ChatProvider?

    public init(
      mode: SessionMode,
      question: Question? = nil,
      topicIds: [String] = [],
      difficulty: Difficulty? = nil,
      durationSeconds: Int? = nil,
      hintBudget: Int = 3,
      provider: ChatProvider? = nil
    ) {
      self.mode = mode
      self.question = question
      self.topicIds = topicIds
      self.difficulty = difficulty
      self.durationSeconds = durationSeconds
      self.hintBudget = hintBudget
      self.provider = provider
    }
  }

  /// Starts a new interview session: creates the attempt (with workspace),
  /// builds a chat context with mode-specific prompts, starts the timer.
  public func startNewSession(_ request: NewSessionRequest) async {
    let initialized = await ensureInitialized()
    guard initialized else { return }

    await persistVisibleSessionMessages()
    retainCurrentSessionContext()

    if let provider = request.provider, let globalPreferences {
      globalPreferences.chatProvider = provider
    }

    let provider = globalPreferences?.chatProvider.rawValue ?? "claude"
    let attempt: InterviewAttempt
    do {
      attempt = try await interviewSession.beginAttempt(
        mode: request.mode,
        question: request.question,
        durationSeconds: request.durationSeconds,
        hintBudget: request.hintBudget,
        provider: provider
      )
    } catch {
      initError = error
      return
    }

    let context: ChatSessionContext
    do {
      context = try makeSessionContext(mode: request.mode, workingDirectory: attempt.workspacePath)
    } catch {
      initError = error
      return
    }

    activateContext(context)
    pendingSessionContextsByViewModelId[ObjectIdentifier(context.viewModel)] = context

    setCurrentWorkingDirectory(attempt.workspacePath ?? context.viewModel.projectPath)
    setCurrentSessionId(nil)
    refreshCurrentWorkspaceUsage()
    evaluationRepairAttempts = 0

    if let duration = request.durationSeconds {
      sessionTimer.start(duration: TimeInterval(duration))
    } else {
      sessionTimer.stop()
    }

    // Kick off the interview: the agent presents the question (retry from
    // bank) or generates one for the requested topics.
    if request.mode != .practice {
      sendKickoffMessage(for: request)
    }
  }

  /// Legacy entry point (pre-interview flows): starts an untimed practice session.
  public func startNewSession(workingDirectory: String?) async {
    let initialized = await ensureInitialized()
    guard initialized else { return }

    await persistVisibleSessionMessages()
    retainCurrentSessionContext()

    let context: ChatSessionContext
    do {
      context = try makeSessionContext(mode: .practice, workingDirectory: workingDirectory)
    } catch {
      initError = error
      return
    }

    activateContext(context)
    pendingSessionContextsByViewModelId[ObjectIdentifier(context.viewModel)] = context
    setCurrentWorkingDirectory(normalized(workingDirectory) ?? context.viewModel.projectPath)
    setCurrentSessionId(nil)
    refreshCurrentWorkspaceUsage()
    interviewSession.clearActiveAttempt()
    sessionTimer.stop()
  }

  private func sendKickoffMessage(for request: NewSessionRequest) {
    let text: String
    if let question = request.question {
      text = """
        Let's begin. Use this exact question from my bank (re-emit its \
        buddy-question fence with the same title and prompt):

        Title: \(question.title)
        Difficulty: \(question.difficulty.rawValue)
        Topics: \(question.topicIds.joined(separator: ", "))

        \(question.promptMarkdown)
        """
    } else {
      var constraints: [String] = []
      if !request.topicIds.isEmpty {
        constraints.append("Topics: \(request.topicIds.joined(separator: ", "))")
      }
      if let difficulty = request.difficulty {
        constraints.append("Difficulty: \(difficulty.rawValue)")
      }
      text = constraints.isEmpty
        ? "Let's begin. Present my first question."
        : "Let's begin. Present my first question.\n\(constraints.joined(separator: "\n"))"
    }
    sendMessageToViewModel(text)
  }

  // MARK: - Hints / grading

  /// Deterministic hint request: sends the canonical marker and increments the counter.
  public func requestHint() {
    guard let attempt = interviewSession.activeAttempt, attempt.status == .inProgress else { return }
    Task { await interviewSession.recordHintUsed() }
    sendMessageToViewModel(BuddyAgentInstructions.hintRequestMessage)
  }

  /// Coaching review of the saved solution: the agent reads the workspace
  /// file and locates failures / confirms correctness without revealing the
  /// solution (review contract in the system prompt). Free — no hint cost.
  public func requestReview(fileName: String? = nil) {
    guard let attempt = interviewSession.activeAttempt, attempt.status == .inProgress else { return }
    sendMessageToViewModel(BuddyAgentInstructions.reviewRequestMessage(fileName: fileName))
  }

  public func requestWhiteboard() {
    guard currentMode == .systemDesign,
          interviewSession.activeAttempt?.status == .inProgress else {
      return
    }
    sendMessageToViewModel(BuddyAgentInstructions.whiteboardRequestMessage)
  }

  /// "End & grade": transitions the attempt and sends the evaluation directive.
  public func endAndGrade() async {
    guard let attempt = interviewSession.activeAttempt, attempt.status == .inProgress else { return }
    sessionTimer.stop()
    await interviewSession.requestEvaluation()
    evaluationRepairAttempts = 0
    // Grade with the specialization the session was created under, falling
    // back to the current setting for restored sessions.
    let specialization = activeSessionContext?.specialization ?? interviewSettings.specialization
    sendMessageToViewModel(
      BuddyAgentInstructions.evaluationDirective(mode: attempt.mode, specialization: specialization)
    )
  }

  private func handleTimerExpired() async {
    await endAndGrade()
  }

  // MARK: - Session Management

  public func switchToSession(_ session: StoredSession) async {
    let initialized = await ensureInitialized()
    guard initialized else { return }

    await persistVisibleSessionMessages()
    retainCurrentSessionContext()

    // Load fresh session data from storage, fall back to the passed object
    let sessionToLoad: StoredSession
    if let stored = try? await sessionStorage.getSession(id: session.id) {
      sessionToLoad = stored
    } else {
      sessionToLoad = session
    }

    // Restore the attempt (and its mode) linked to this chat session.
    let restoredAttempt = await interviewSession.restoreAttempt(forChatSessionId: sessionToLoad.id)
    let mode = restoredAttempt?.mode ?? .practice

    let context: ChatSessionContext
    if let existingContext = sessionContextsById[sessionToLoad.id] {
      context = existingContext
    } else {
      do {
        context = try makeSessionContext(mode: mode, workingDirectory: sessionToLoad.workingDirectory)
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
    evaluationRepairAttempts = 0
    restoreTimer(for: restoredAttempt)
  }

  /// Relaunch/switch mid-attempt: resumes the countdown from the persisted
  /// deadline, or auto-expires if it already passed.
  private func restoreTimer(for attempt: InterviewAttempt?) {
    guard let attempt,
          attempt.status == .inProgress,
          let duration = attempt.plannedDurationSeconds else {
      sessionTimer.stop()
      return
    }

    let deadline = attempt.startedAt.addingTimeInterval(TimeInterval(duration))
    sessionTimer.start(deadline: deadline, totalDuration: TimeInterval(duration))
  }

  public func deleteSession(_ session: StoredSession) async {
    do {
      try await interviewSession.deleteAttempt(forChatSessionId: session.id)
      try await sessionStorage.deleteSession(id: session.id)
    } catch {
      chatLog.error(
        "Could not delete session \(session.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      return
    }

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
      interviewSession.clearActiveAttempt()
      sessionTimer.stop()
      setCurrentWorkingDirectory(nil)
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
    interviewSession.clearActiveAttempt()
    sessionTimer.stop()
  }

  // MARK: - Private

  private func ensureInitialized() async -> Bool {
    if !isInitialized {
      await initialize()
    }

    return isInitialized
  }

  private func persistVisibleSessionMessages() async {
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }
  }

  private func makeSessionContext(
    mode: SessionMode,
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

    let specialization = interviewSettings.specialization
    let prefixes = BuddyAgentInstructions.prefixes(for: mode, specialization: specialization)

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
      systemPromptPrefix: prefixes.claude,
      codexDeveloperInstructionsPrefix: prefixes.codex,
      apiInstructionsPrefix: prefixes.api,
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
      self?.makeHiddenContext(for: viewModel)
    }
    viewModel.onAssistantTurnCompleted = { [weak self, weak viewModel] _, message in
      guard let self, let viewModel, self.isVisibleViewModel(viewModel) else { return }
      self.handleAssistantTurnCompleted(message, mode: mode)
    }

    let mcpContextKey = UUID().uuidString
    viewModel.onMCPToolUse = { [weak self, weak viewModel] toolUseId, toolName, argumentsJSON in
      guard let self, let viewModel else { return }
      self.mcpApps.recordToolUse(
        contextKey: mcpContextKey,
        provider: self.mcpProviderKind,
        projectPath: viewModel.projectPath,
        toolUseId: toolUseId,
        toolName: toolName,
        argumentsJSON: argumentsJSON
      )
    }
    viewModel.onMCPToolResult = { [weak self] toolUseId, resultJSON in
      self?.mcpApps.recordToolResult(
        contextKey: mcpContextKey,
        toolUseId: toolUseId,
        resultJSON: resultJSON
      )
    }

    return ChatSessionContext(
      viewModel: viewModel,
      deps: container,
      reference: reference,
      mode: mode,
      specialization: specialization,
      mcpContextKey: mcpContextKey
    )
  }

  // MARK: - Structured block capture

  private func handleAssistantTurnCompleted(_ message: ChatMessage, mode: SessionMode) {
    guard !capturedAssistantMessageIds.contains(message.id) else { return }
    capturedAssistantMessageIds.insert(message.id)

    let attempt = interviewSession.activeAttempt
    let results = StructuredBlockCapture.capture(
      messageText: message.content,
      mode: mode,
      attemptId: attempt?.id
    )

    var capturedEvaluation = false
    Task { @MainActor in
      for result in results {
        switch result {
        case .question(let captured):
          await questionBank.save(captured.question)
          if interviewSession.activeAttempt?.questionId == nil {
            await interviewSession.attachQuestion(captured.question)
          }
        case .evaluation(let captured):
          capturedEvaluation = true
          await interviewSession.completeEvaluation(captured.evaluation, notes: captured.notes)
          await skillStats.refresh()
        }
      }

      // Repair loop: awaiting evaluation but no parseable buddy-eval fence.
      if !capturedEvaluation,
         let attempt = interviewSession.activeAttempt,
         attempt.status == .awaitingEvaluation,
         evaluationRepairAttempts < maxEvaluationRepairAttempts {
        evaluationRepairAttempts += 1
        sendMessageToViewModel(BuddyAgentInstructions.evaluationRepairDirective())
      }
    }
  }

  // MARK: - Context plumbing

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

    // Soft-link the chat session into the active attempt row.
    Task { await interviewSession.linkChatSession(sessionId) }

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

  private func makeHiddenContext(for viewModel: ChatViewModel?) -> String {
    // Interview context only applies to the visible session's attempt.
    guard isVisibleViewModel(viewModel), let attempt = interviewSession.activeAttempt else {
      let workingDirectory = normalized(viewModel?.projectPath) ?? currentWorkingDirectory
      if let workingDirectory {
        return "Workspace directory: \(workingDirectory)"
      }
      return ""
    }

    let phase: BuddyAgentInstructions.AttemptPhase =
      attempt.status == .awaitingEvaluation ? .awaitingEvaluation : .inProgress

    return BuddyAgentInstructions.appendingHiddenContext(
      nil,
      attempt: attempt,
      question: interviewSession.activeQuestion,
      timerRemaining: sessionTimer.remaining,
      phase: phase
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

  // MARK: - MCP Apps (whiteboard surface)

  var mcpProviderKind: SessionProviderKind {
    switch globalPreferences?.chatProvider {
    case .codex: return .codex
    default: return .claude
    }
  }

  /// Renderable MCP apps for the visible session, fed to the whiteboard panel.
  public var currentMCPRenderItems: [MCPAppRenderItem] {
    guard let context = activeSessionContext else { return [] }
    return mcpApps.renderItems(
      provider: mcpProviderKind,
      projectPath: context.viewModel.projectPath,
      contextKey: context.mcpContextKey
    )
  }
}
