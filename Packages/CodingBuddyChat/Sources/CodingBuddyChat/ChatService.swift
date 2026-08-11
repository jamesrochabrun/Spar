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
import KnowledgeKit
import OSLog

private let chatLog = Logger(subsystem: "com.codingbuddy.chat", category: "ChatService")

struct ChatSessionContext {
  let viewModel: ChatViewModel
  let deps: DependencyContainer
  let reference: ChatViewModelReference
  let mode: SessionMode
  let specialization: InterviewSpecialization
  let knowledgeConfiguration: KnowledgeSessionConfiguration?
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
  /// Changes after each visible assistant turn so workspace surfaces can pick
  /// up files written by provider tools without discarding unsaved user edits.
  public private(set) var workspaceRevision = 0
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
  public let knowledgeLibrary: KnowledgeLibraryService
  /// Interview preferences (specialization track). Read at session-context
  /// creation, so a settings change applies to the next session started.
  public let interviewSettings: BuddyInterviewSettings

  /// Mode of the currently visible session, driving surface availability.
  public var currentMode: SessionMode? { activeSessionContext?.mode }
  public var currentKnowledgeConfiguration: KnowledgeSessionConfiguration? {
    activeSessionContext?.knowledgeConfiguration
  }
  public var currentKnowledgeStudySpaceID: String? {
    currentKnowledgeConfiguration?.studySpaceID
  }
  public var currentKnowledgeSourcesAreOpen: Bool {
    currentKnowledgeConfiguration?.sourceAccess == .openBook
  }

  /// True while the visible session is a repository learning session, which is
  /// what puts the Lesson surface on screen.
  public var isLearningSession: Bool {
    currentKnowledgeConfiguration?.activity == .learn
  }

  /// The lesson the visible session is on. Keyed by view model so switching
  /// sessions never shows another session's lesson.
  public var currentLesson: Lesson? {
    guard let chatViewModel else { return nil }
    return lessonByViewModelID[ObjectIdentifier(chatViewModel)]
  }

  public var currentStudyPlan: StudyPlan? {
    knowledgeLibrary.studyPlan(studySpaceID: currentKnowledgeStudySpaceID)
  }

  public var currentStudySpaceName: String? {
    knowledgeLibrary.studySpace(id: currentKnowledgeStudySpaceID)?.name
  }

  /// The study-plan item the lesson panel is showing, resolved against the
  /// saved plan so completion state stays authoritative.
  public var currentLessonItem: StudyPlanItem? {
    guard let itemID = currentLesson?.itemID ?? lastRequestedStudyItemID else { return nil }
    return currentStudyPlan?.items.first { $0.id == itemID }
  }

  /// 1-based position of the current item in the plan.
  public var currentLessonItemNumber: Int? {
    guard let item = currentLessonItem,
          let index = currentStudyPlan?.items.firstIndex(where: { $0.id == item.id }) else {
      return nil
    }
    return index + 1
  }

  /// True between sending a lesson turn and the fence coming back.
  public var isLessonLoading: Bool {
    chatViewModel?.isLoading == true
  }

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
  private var pendingStudyPlanGenerationSpaceIDs: Set<String> = []
  private var studyPlanRepairAttemptsBySpaceID: [String: Int] = [:]
  private let maxStudyPlanRepairAttempts = 2
  private var lessonByViewModelID: [ObjectIdentifier: Lesson] = [:]
  /// Item id of the most recent lesson turn we asked for, used to attribute a
  /// fence that omitted `item_id` and to scope the repair loop.
  private var lastRequestedStudyItemID: String?
  private var lessonRepairAttemptsByItemID: [String: Int] = [:]
  private let maxLessonRepairAttempts = 1

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol = SimplifiedClaudeCodeSQLiteStorage(),
    interviewStorage: (any InterviewStorageProtocol)? = nil,
    workspaceManager: (any InterviewWorkspaceManaging)? = nil,
    interviewSettings: BuddyInterviewSettings? = nil,
    knowledgeLibrary: KnowledgeLibraryService? = nil,
    persistentPreferencesManager: PersistentPreferencesManager? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    logger: ClaudeCodeLogger = ClaudeCodeLogger()
  ) {
    let resolvedInterviewStorage = interviewStorage ?? InterviewSQLiteStorage()
    self.sessionStorage = sessionStorage
    self.interviewStorage = resolvedInterviewStorage
    self.interviewSettings = interviewSettings ?? BuddyInterviewSettings()
    self.knowledgeLibrary = knowledgeLibrary ?? KnowledgeLibraryService()
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
      await knowledgeLibrary.load()
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

  public func openKnowledgeCitation(_ url: URL) -> Bool {
    guard url.scheme == "codingbuddy-source",
          url.host == "chunk" else {
      return false
    }
    let chunkID = url.pathComponents.last ?? ""
    guard !chunkID.isEmpty else { return false }
    Task {
      await knowledgeLibrary.openCitation(chunkID: chunkID)
    }
    return true
  }

  // MARK: - Interview session lifecycle

  public enum StudyPlanFocus: Equatable, Sendable {
    case next
    case random
    case item(String)
  }

  public struct NewSessionRequest {
    public var mode: SessionMode
    public var question: Question?
    public var topicIds: [String]
    public var difficulty: Difficulty?
    public var durationSeconds: Int?
    public var hintBudget: Int
    public var provider: ChatProvider?
    public var knowledgeConfiguration: KnowledgeSessionConfiguration?
    public var studyPlanFocus: StudyPlanFocus?

    public init(
      mode: SessionMode,
      question: Question? = nil,
      topicIds: [String] = [],
      difficulty: Difficulty? = nil,
      durationSeconds: Int? = nil,
      hintBudget: Int = 3,
      provider: ChatProvider? = nil,
      knowledgeConfiguration: KnowledgeSessionConfiguration? = nil,
      studyPlanFocus: StudyPlanFocus? = nil
    ) {
      self.mode = mode
      self.question = question
      self.topicIds = topicIds
      self.difficulty = difficulty
      self.durationSeconds = durationSeconds
      self.hintBudget = hintBudget
      self.provider = provider
      self.knowledgeConfiguration = knowledgeConfiguration
      self.studyPlanFocus = studyPlanFocus
    }
  }

  /// Starts a new interview session: creates the attempt (with workspace),
  /// builds a chat context with mode-specific prompts, starts the timer.
  public func startNewSession(_ request: NewSessionRequest) async {
    let initialized = await ensureInitialized()
    guard initialized else { return }

    await persistVisibleSessionMessages()
    retainCurrentSessionContext()
    sessionTimer.stop()

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
        provider: provider,
        requestedDifficulty: request.difficulty ?? request.question?.difficulty ?? .medium
      )
    } catch {
      initError = error
      return
    }

    let context: ChatSessionContext
    do {
      context = try makeSessionContext(
        mode: request.mode,
        workingDirectory: attempt.workspacePath,
        knowledgeConfiguration: request.knowledgeConfiguration
      )
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
    if request.mode != .practice || request.knowledgeConfiguration?.activity == .learn {
      sendKickoffMessage(for: request)
    }
  }

  public func startLearning(
    studySpaceID: String,
    focus: StudyPlanFocus = .next,
    startsNewSession: Bool = false
  ) async {
    let plan = knowledgeLibrary.studyPlan(studySpaceID: studySpaceID)
    if Self.shouldReuseLearningSession(
      currentConfiguration: currentKnowledgeConfiguration,
      requestedStudySpaceID: studySpaceID,
      hasPlan: plan != nil,
      startsNewSession: startsNewSession
    ), let plan {
      sendMessageToViewModel(studyMessage(focus: focus, plan: plan))
      return
    }

    await startNewSession(NewSessionRequest(
      mode: .practice,
      durationSeconds: nil,
      hintBudget: 0,
      provider: globalPreferences?.chatProvider,
      knowledgeConfiguration: KnowledgeSessionConfiguration(
        studySpaceID: studySpaceID,
        activity: .learn,
        sourceAccess: .openBook
      ),
      studyPlanFocus: focus
    ))
  }

  // MARK: - Lesson loop

  /// Sends the learner's answer to the current task. The agent replies with a
  /// fence carrying feedback plus the next task, which lands in `currentLesson`.
  public func submitLessonResponse(_ response: String) {
    let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, isLearningSession else { return }
    sendMessageToViewModel(BuddyAgentInstructions.lessonResponseMessage(trimmed))
  }

  /// "I'm stuck" — narrows the current task without revealing the answer.
  public func requestLessonHelp() {
    guard isLearningSession, currentLesson != nil else { return }
    sendMessageToViewModel(BuddyAgentInstructions.lessonStuckMessage)
  }

  /// Learner-owned completion. The agent never marks items; it only suggests.
  public func setCurrentLessonItemCompletion(_ isCompleted: Bool) async {
    guard let plan = currentStudyPlan,
          let itemID = currentLesson?.itemID ?? lastRequestedStudyItemID,
          plan.items.contains(where: { $0.id == itemID }) else {
      return
    }
    await knowledgeLibrary.setStudyPlanItemCompletion(
      planID: plan.id,
      itemID: itemID,
      isCompleted: isCompleted
    )
  }

  /// Continues in the same session with the next incomplete plan item.
  public func startNextLessonItem() async {
    guard let studySpaceID = currentKnowledgeStudySpaceID else { return }
    await startLearning(studySpaceID: studySpaceID, focus: .next)
  }

  /// Reveals the passage a lesson cites on the Sources surface.
  public func openLessonSource(_ source: Lesson.SourceReference) async {
    guard let studySpaceID = currentKnowledgeStudySpaceID else { return }
    await knowledgeLibrary.openLessonSource(
      studySpaceID: studySpaceID,
      path: source.path,
      chunkID: source.chunkID
    )
  }

  static func shouldReuseLearningSession(
    currentConfiguration: KnowledgeSessionConfiguration?,
    requestedStudySpaceID: String,
    hasPlan: Bool,
    startsNewSession: Bool
  ) -> Bool {
    !startsNewSession &&
      hasPlan &&
      currentConfiguration?.studySpaceID == requestedStudySpaceID &&
      currentConfiguration?.activity == .learn
  }

  /// Legacy entry point (pre-interview flows): starts an untimed practice session.
  public func startNewSession(workingDirectory: String?) async {
    let initialized = await ensureInitialized()
    guard initialized else { return }

    await persistVisibleSessionMessages()
    retainCurrentSessionContext()
    sessionTimer.stop()

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
    await interviewSession.leaveActiveAttempt()
  }

  private func sendKickoffMessage(for request: NewSessionRequest) {
    var text: String
    if let configuration = request.knowledgeConfiguration,
       configuration.activity == .learn {
      let studySpace = knowledgeLibrary.studySpace(id: configuration.studySpaceID)
      let existingPlan = knowledgeLibrary.studyPlan(studySpaceID: configuration.studySpaceID)
      if existingPlan == nil {
        pendingStudyPlanGenerationSpaceIDs.insert(configuration.studySpaceID)
        let requestedItemID: String?
        if case .item(let itemID) = request.studyPlanFocus {
          requestedItemID = itemID
        } else {
          requestedItemID = nil
        }
        text = BuddyAgentInstructions.studyPlanGenerationDirective(
          studySpaceName: studySpace?.name ?? "this repository",
          requestedItemID: requestedItemID
        )
      } else {
        text = studyMessage(focus: request.studyPlanFocus ?? .next, plan: existingPlan)
      }
    } else if let question = request.question {
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
      if request.knowledgeConfiguration != nil {
        constraints.append(
          "Ground the question in the study-space source excerpts provided in context — ask about this repository's actual code, architecture, or design decisions."
        )
      }
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
    // System design gets its shared canvas in the very first turn so the
    // candidate can diagram while clarifying — no separate create step.
    // (Learning sessions kick off with a study plan, never a whiteboard.)
    if request.mode == .systemDesign, request.knowledgeConfiguration?.activity != .learn {
      text += "\n\n" + BuddyAgentInstructions.systemDesignKickoffWhiteboardDirective
    }
    sendMessageToViewModel(text)
  }

  private func studyMessage(focus: StudyPlanFocus, plan: StudyPlan?) -> String {
    switch focus {
    case .next:
      guard let item = plan?.nextIncompleteItem else {
        beginLessonTurn(itemID: nil)
        return BuddyAgentInstructions.nextStudyTopicMessage
      }
      return studyTopicMessage(for: item, plan: plan)
    case .random:
      let candidates = plan?.items.filter { !$0.isCompleted }
      guard let item = candidates?.randomElement() ?? plan?.items.randomElement() else {
        beginLessonTurn(itemID: nil)
        return BuddyAgentInstructions.randomStudyTopicMessage
      }
      return studyTopicMessage(for: item, plan: plan)
    case .item(let itemID):
      guard let item = plan?.items.first(where: { $0.id == itemID }) else {
        beginLessonTurn(itemID: itemID)
        return BuddyAgentInstructions.studyTopicRequestMessage(itemID: itemID)
      }
      return studyTopicMessage(for: item, plan: plan)
    }
  }

  private func studyTopicMessage(for item: StudyPlanItem, plan: StudyPlan?) -> String {
    beginLessonTurn(itemID: item.id)
    let itemNumber = plan?.items.firstIndex(where: { $0.id == item.id }).map { $0 + 1 }
    return BuddyAgentInstructions.studyTopicRequestMessage(
      itemID: item.id,
      title: item.title,
      itemNumber: itemNumber,
      totalItemCount: plan?.items.count
    )
  }

  /// Arms the lesson panel for a new item: a lesson from a *different* item is
  /// cleared so the panel shows "preparing" instead of stale content, while a
  /// re-request of the same item keeps its card on screen until the next fence.
  private func beginLessonTurn(itemID: String?) {
    lastRequestedStudyItemID = itemID
    guard let chatViewModel else { return }
    let key = ObjectIdentifier(chatViewModel)
    if lessonByViewModelID[key]?.itemID != itemID {
      lessonByViewModelID[key] = nil
    }
    if let itemID {
      lessonRepairAttemptsByItemID[itemID] = 0
    }
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

  public var canRequestWhiteboard: Bool {
    SystemDesignWhiteboardRequestPolicy.canRequest(
      mode: currentMode,
      attemptStatus: interviewSession.activeAttempt?.status,
      isChatLoading: chatViewModel?.isLoading == true,
      hasChatViewModel: chatViewModel != nil
    )
  }

  @discardableResult
  public func requestWhiteboard() -> Bool {
    guard canRequestWhiteboard else { return false }
    sendMessageToViewModel(BuddyAgentInstructions.whiteboardRequestMessage)
    return true
  }

  public var canRequestWhiteboardReview: Bool {
    SystemDesignWhiteboardRequestPolicy.canRequestReview(
      attemptStatus: interviewSession.activeAttempt?.status,
      isChatLoading: chatViewModel?.isLoading == true,
      hasRenderItems: !currentMCPRenderItems.isEmpty
    )
  }

  /// Asks the agent to re-read the shared canvas checkpoint (and any workspace
  /// code) and coach on the current design. Free — no hint cost.
  @discardableResult
  public func requestWhiteboardReview() -> Bool {
    guard canRequestWhiteboardReview else { return false }
    sendMessageToViewModel(BuddyAgentInstructions.whiteboardReviewRequestMessage)
    return true
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
    sessionTimer.stop()

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
    let knowledgeConfiguration = await knowledgeLibrary.sessionConfiguration(
      chatSessionID: sessionToLoad.id
    )

    let context: ChatSessionContext
    if let existingContext = sessionContextsById[sessionToLoad.id] {
      context = existingContext
    } else {
      do {
        context = try makeSessionContext(
          mode: mode,
          workingDirectory: sessionToLoad.workingDirectory,
          knowledgeConfiguration: knowledgeConfiguration
        )
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

    // Rehydrate the session's whiteboard from the persisted invocations (a
    // context that already captured live invocations keeps them instead).
    await mcpApps.restoreChatSession(
      sessionToLoad.id,
      contextKey: context.mcpContextKey,
      provider: mcpProviderKind,
      projectPath: context.viewModel.projectPath
    )

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
      await knowledgeLibrary.deleteSessionBinding(chatSessionID: session.id)
      try await sessionStorage.deleteSession(id: session.id)
    } catch {
      chatLog.error(
        "Could not delete session \(session.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      return
    }

    await mcpApps.deleteStoredInvocations(chatSessionId: session.id)

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

  public func clearActiveWorkspace() async {
    sessionTimer.stop()

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
    await interviewSession.leaveActiveAttempt()
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
    workingDirectory: String? = nil,
    knowledgeConfiguration: KnowledgeSessionConfiguration? = nil
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
    let prefixes = BuddyAgentInstructions.prefixes(
      for: mode,
      specialization: specialization,
      knowledgeConfiguration: knowledgeConfiguration
    )

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
    viewModel.outgoingContextAugmenter = { [weak self, weak viewModel] query in
      guard let self,
            let viewModel,
            let configuration = self.context(for: viewModel)?.knowledgeConfiguration else {
        return nil
      }
      return await self.knowledgeLibrary.makeContext(
        configuration: configuration,
        query: query
      )
    }
    viewModel.onAssistantTurnCompleted = { [weak self, weak viewModel] _, message in
      guard let self, let viewModel, self.isVisibleViewModel(viewModel) else { return }
      self.handleAssistantTurnCompleted(message, mode: mode, viewModel: viewModel)
      self.reconcileMCPApps(for: viewModel)
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
      knowledgeConfiguration: knowledgeConfiguration,
      mcpContextKey: mcpContextKey
    )
  }

  // MARK: - Structured block capture

  private func handleAssistantTurnCompleted(
    _ message: ChatMessage,
    mode: SessionMode,
    viewModel: ChatViewModel
  ) {
    guard !capturedAssistantMessageIds.contains(message.id) else { return }
    capturedAssistantMessageIds.insert(message.id)
    workspaceRevision += 1

    let attempt = interviewSession.activeAttempt
    let results = StructuredBlockCapture.capture(
      messageText: message.content,
      mode: mode,
      attemptId: attempt?.id,
      nextRepIndex: interviewSession.drillRun.nextIndex
    )

    var capturedEvaluation = false
    Task { @MainActor in
      if let configuration = context(for: viewModel)?.knowledgeConfiguration,
         configuration.activity == .learn {
        let plans = StudyPlanBlockParser.parseBlocks(
          in: message.content,
          studySpaceID: configuration.studySpaceID
        )
        if let plan = plans.last {
          let saved = await knowledgeLibrary.saveGeneratedStudyPlan(plan)
          if saved {
            pendingStudyPlanGenerationSpaceIDs.remove(configuration.studySpaceID)
            studyPlanRepairAttemptsBySpaceID.removeValue(forKey: configuration.studySpaceID)
          }
        } else if pendingStudyPlanGenerationSpaceIDs.contains(configuration.studySpaceID) {
          let repairAttempts = studyPlanRepairAttemptsBySpaceID[configuration.studySpaceID] ?? 0
          if repairAttempts < maxStudyPlanRepairAttempts {
            studyPlanRepairAttemptsBySpaceID[configuration.studySpaceID] = repairAttempts + 1
            sendMessageToViewModel(BuddyAgentInstructions.studyPlanRepairDirective())
          }
        }

        captureLesson(in: message.content, viewModel: viewModel)
      }

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
        case .drillRep(let captured):
          interviewSession.recordDrillRep(captured.rep)
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

  /// Stores the turn's `buddy-lesson` fence for the Lesson surface, backfilling
  /// what the agent left out from the saved plan. When a lesson was requested
  /// and no fence arrived, asks once for the block rather than leaving the
  /// panel blank next to a wall of chat prose.
  private func captureLesson(in messageText: String, viewModel: ChatViewModel) {
    guard let lesson = LessonBlockParser.parseBlocks(in: messageText).last else {
      // Only chase a missing fence when the panel has nothing to show for the
      // item we just started. Once a task is on screen, a prose-only turn is a
      // legitimate answer to a side question, not a contract violation.
      guard let itemID = lastRequestedStudyItemID,
            lessonByViewModelID[ObjectIdentifier(viewModel)] == nil,
            (lessonRepairAttemptsByItemID[itemID] ?? 0) < maxLessonRepairAttempts else {
        return
      }
      lessonRepairAttemptsByItemID[itemID] = (lessonRepairAttemptsByItemID[itemID] ?? 0) + 1
      sendMessageToViewModel(BuddyAgentInstructions.lessonRepairDirective())
      return
    }

    let resolved = Self.resolveLesson(
      lesson,
      requestedItemID: lastRequestedStudyItemID,
      plan: currentStudyPlan
    )
    if !resolved.itemID.isEmpty {
      lastRequestedStudyItemID = resolved.itemID
    }
    lessonByViewModelID[ObjectIdentifier(viewModel)] = resolved
  }

  /// Reconciles a parsed fence with what the app already knows: the agent can
  /// omit `item_id`/`item_title`, or name an item the saved plan doesn't have.
  /// Completion is keyed on the item id, so a wrong one would silently orphan
  /// the learner's checkmark — the requested item wins whenever the fence's id
  /// isn't in the plan.
  static func resolveLesson(
    _ lesson: Lesson,
    requestedItemID: String?,
    plan: StudyPlan?
  ) -> Lesson {
    var resolved = lesson
    let isKnownItem = plan?.items.contains { $0.id == resolved.itemID } == true
    if !isKnownItem, let requestedItemID {
      resolved.itemID = requestedItemID
    }
    if resolved.itemTitle.isEmpty {
      resolved.itemTitle = plan?.items.first { $0.id == resolved.itemID }?.title ?? ""
    }
    return resolved
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
    mcpApps.bindChatSession(sessionId, contextKey: context.mcpContextKey)
    reconcileMCPApps(
      context: context,
      chatSessionId: sessionId
    )

    guard isVisibleViewModel(viewModel) else {
      onSessionChanged?()
      return
    }

    // Soft-link the chat session into the active attempt row.
    Task { await interviewSession.linkChatSession(sessionId) }
    if let configuration = context.knowledgeConfiguration {
      Task {
        await knowledgeLibrary.saveSessionBinding(
          chatSessionID: sessionId,
          configuration: configuration
        )
      }
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

  /// Reconciles live MCP capture with the provider's persisted transcript.
  /// Claude's SDK stream can omit tool-result correlation in production, while
  /// its JSONL always carries tool_use.id/tool_result.tool_use_id. Running this
  /// after each completed turn gives an open canvas its checkpoint id promptly;
  /// running it at session binding/restoration makes relaunch deterministic.
  private func reconcileMCPApps(for viewModel: ChatViewModel) {
    let viewModelID = ObjectIdentifier(viewModel)
    guard let context = context(for: viewModel),
          let chatSessionId = sessionIdByViewModelId[viewModelID] else {
      return
    }
    reconcileMCPApps(context: context, chatSessionId: chatSessionId)
  }

  private func reconcileMCPApps(
    context: ChatSessionContext,
    chatSessionId: String
  ) {
    let provider = mcpProviderKind
    let projectPath = context.viewModel.projectPath
    Task { [mcpApps] in
      await mcpApps.restoreChatSession(
        chatSessionId,
        contextKey: context.mcpContextKey,
        provider: provider,
        projectPath: projectPath
      )
    }
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

    let whiteboardContext = whiteboardHiddenContext()

    let phase: BuddyAgentInstructions.AttemptPhase
    switch attempt.status {
    case .inProgress:
      phase = .inProgress
    case .awaitingEvaluation:
      phase = .awaitingEvaluation
    case .evaluated:
      phase = .evaluated
    case .abandoned:
      phase = .abandoned
    }

    return BuddyAgentInstructions.appendingHiddenContext(
      whiteboardContext,
      attempt: attempt,
      question: interviewSession.activeQuestion,
      timerRemaining: sessionTimer.remaining,
      phase: phase,
      drillRun: interviewSession.drillRun,
      suggestedDifficulty: attempt.mode == .drill ? interviewSession.suggestedNextDifficulty : nil
    )
  }

  /// The whiteboard app's own summary of edits the user made since the agent
  /// last saw the canvas (`ui/update-model-context`). Consumed on send so each
  /// summary reaches the agent exactly once; the agent reads the checkpoint for
  /// the full scene.
  private func whiteboardHiddenContext() -> String? {
    let texts = mcpApps.consumeModelContextTexts(for: currentMCPRenderItems)
    guard !texts.isEmpty else { return nil }
    return "Whiteboard update (user edits on the shared canvas):\n" + texts.joined(separator: "\n")
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
