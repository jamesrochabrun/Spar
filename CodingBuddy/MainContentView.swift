//
//  MainContentView.swift
//  Spar
//

import BuddyMCPApps
import ClaudeCodeCore
import CodingBuddyChat
import CodingBuddyKit
import InterviewKit
import KnowledgeKit
import SwiftUI

struct MainContentView: View {
  @Bindable var appState: AppState
  let initialPrompt: String
  let chatService: ChatService
  let voiceController: CodingBuddyVoiceController

  @State private var sidebarViewModel: SidebarViewModel?
  @State private var panelLayoutState: CanvasPanelLayoutState = .allPanels
  @State private var didHandleInitialPrompt = false
  @State private var sheetTopics: [Topic] = []
  @State private var sheetBankQuestions: [Question] = []
  @State private var selectedSurface: StudioSurface = .workspace
  @State private var contentMode: MainContentMode = .session
  @State private var isReportGenerationRequested = false
  @State private var isChatInputFocusRequested = false
  @State private var isWhiteboardCreationRequested = false
  @State private var isLessonLibraryPresented = false
  @State private var isVoiceTranscriptPresented = false
  @State private var isVoiceOnboardingPresented = false
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let chatPanelWidth: CGFloat = 380
  private let sidebarWidth: CGFloat = 340
  private let windowControlLeadingReserve: CGFloat = 78

  var body: some View {
    HStack(spacing: 0) {
      if let sidebarVM = sidebarViewModel, shouldShowSidebar {
        SidebarView(
          sidebarViewModel: sidebarVM,
          reservesWindowControls: true,
          newSessionSheetProvider: { AnyView(newSessionSheet(for: sidebarVM)) },
          knowledgeLibrarySheetProvider: { AnyView(knowledgeLibrarySheet) }
        )
        .frame(width: sidebarWidth)
          .frame(maxHeight: .infinity)
          .transition(.move(edge: .leading))

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(width: 1)
      }

      if contentMode == .dashboard {
        dashboardPanel
      } else {
        if panelLayoutState.showsChatPanel {
          VStack(spacing: 0) {
            HStack {
              leadingToolbarButtons

              Spacer()
            }
            .padding(.leading, chatToolbarLeadingPadding)
            .padding(.trailing, EaselDesignSystem.Spacing.large)
            .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
            .background(EaselDesignSystem.Palette.surface(for: colorScheme))

            Rectangle()
              .fill(EaselDesignSystem.Palette.border(for: colorScheme))
              .frame(height: 1)

            ChatPanelView(
              chatService: chatService,
              voiceController: voiceController,
              isVoiceTranscriptPresented: isVoiceTranscriptPresented,
              onVoiceTranscriptToggle: toggleVoiceTranscript,
              triggerInputFocus: $isChatInputFocusRequested
            )
              .frame(maxHeight: .infinity)
          }
          .frame(width: chatPanelWidth)
          .frame(maxHeight: .infinity)
          .transition(.move(edge: .leading).combined(with: .opacity))

          Rectangle()
            .fill(EaselDesignSystem.Palette.border(for: colorScheme))
            .frame(width: 1)
        }

        studioSurfacePanel
      }
    }
    .animation(.easeInOut(duration: 0.22), value: contentMode)
    .background(alignment: .topLeading) {
      // Hidden button hosts the window-level keyboard shortcut.
      Button("Cycle panel layout", action: cyclePanelLayout)
        .keyboardShortcut("b", modifiers: .command)
        .buttonStyle(.plain)
        .frame(width: 1, height: 1)
        .opacity(0.001)
        .accessibilityHidden(true)
    }
    .animation(.easeInOut(duration: 0.25), value: panelLayoutState)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .ignoresSafeArea(.container, edges: .top)
    .tint(EaselDesignSystem.Palette.accent)
    .task {
      let vm = SidebarViewModel(
        sessionStorage: chatService.sessionStorage,
        interviewStorage: chatService.interviewStorage
      )
      vm.onSessionSelected = { session in
        contentMode.showSession()
        Task {
          await chatService.initialize()
          await chatService.switchToSession(session)
          await vm.loadSessions()
        }
      }
      vm.onStartSession = { request in
        contentMode.showSession()
        isReportGenerationRequested = false
        selectedSurface = StudioSurface.defaultSurface(
          for: request.mode,
          isLearningSession: request.knowledgeConfiguration?.activity == .learn
        )
        Task {
          await chatService.initialize()
          await chatService.startNewSession(request)
          await vm.loadSessions()
        }
      }
      chatService.onEvaluationRecorded = { _ in
        isReportGenerationRequested = false
        selectedSurface = .report
      }
      vm.onDashboardToggle = {
        contentMode.toggleDashboard()
      }
      vm.onDeleteSession = { session in
        Task {
          await chatService.deleteSession(session)
          await vm.loadSessions()
        }
      }
      chatService.onSessionChanged = {
        Task {
          if let currentSessionId = chatService.currentSessionId {
            vm.completePendingNewSession(sessionId: currentSessionId)
          }
          await vm.loadSessions()
        }
      }
      vm.isSidebarVisible = shouldShowSidebar
      sidebarViewModel = vm

      if !didHandleInitialPrompt {
        didHandleInitialPrompt = true
        let trimmedPrompt = initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty {
          await chatService.initialize()
          chatService.sendMessage(trimmedPrompt, context: nil, hiddenContext: nil)
        }
      }
    }
    .onChange(of: voiceController.onboardingPresentationRequest) { _, _ in
      isVoiceOnboardingPresented = true
    }
    .onChange(of: voiceController.conversationStatus) { _, status in
      handleVoiceStatusChange(status)
    }
    .onChange(of: chatService.currentSessionId) { _, _ in
      isVoiceTranscriptPresented = false
      voiceController.handleSessionChange()
    }
    .onChange(of: contentMode) { _, mode in
      if mode == .dashboard {
        isVoiceTranscriptPresented = false
        voiceController.stop()
      }
    }
    .onDisappear {
      voiceController.stop()
    }
    .sheet(isPresented: $isVoiceOnboardingPresented) {
      CodingBuddyVoiceOnboardingView(
        onStartVoiceCoach: voiceController.toggleConversation,
        onDismiss: dismissVoiceOnboarding
      )
    }
  }

  private var shouldShowSidebar: Bool {
    panelLayoutState.showsSidebar
  }

  /// Shared by the sidebar's button and the Lesson surface, so picking another
  /// item never requires a detour through the sidebar.
  private var knowledgeLibrarySheet: some View {
    KnowledgeLibraryView(
      library: chatService.knowledgeLibrary,
      onStartLearning: { studySpaceID, focus in
        contentMode.showSession()
        isLessonLibraryPresented = false
        selectedSurface = .lesson
        Task {
          await chatService.startLearning(
            studySpaceID: studySpaceID,
            focus: focus,
            startsNewSession: true
          )
          await sidebarViewModel?.loadSessions()
        }
      }
    )
  }

  private var dashboardPanel: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        if !shouldShowSidebar {
          leadingToolbarButtons
        }

        Text("Dashboard")
          .font(EaselDesignSystem.Typography.interface(size: 14, weight: .semibold))

        Spacer()

        Button("Back to Session") {
          contentMode.showSession()
        }
        .controlSize(.small)
      }
      .padding(.leading, shouldShowSidebar ? 16 : windowControlLeadingReserve)
      .padding(.trailing, 16)
      .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
      .background(EaselDesignSystem.Palette.surface(for: colorScheme))

      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)

      DashboardView(
        skillStats: chatService.skillStats,
        onRetryQuestion: { question in
          contentMode.showSession()
          selectedSurface = StudioSurface.defaultSurface(for: question.mode)
          let request = ChatService.NewSessionRequest(
            mode: question.mode,
            question: question,
            durationSeconds: question.mode.isTimedByDefault ? 35 * 60 : nil
          )
          sidebarViewModel?.preparePendingNewSession(
            mode: question.mode,
            provider: chatService.globalPreferences?.chatProvider ?? .claude,
            workingDirectory: nil
          )
          sidebarViewModel?.onStartSession?(request)
        },
        onOpenSession: { chatSessionId in
          contentMode.showSession()
          Task {
            if let session = try? await chatService.sessionStorage.getSession(id: chatSessionId) {
              sidebarViewModel?.selectedSessionId = chatSessionId
              await chatService.switchToSession(session)
              await sidebarViewModel?.loadSessions()
            }
          }
        },
        questionProvider: { questionId in
          await chatService.questionBank.question(id: questionId)
        }
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func newSessionSheet(for sidebarVM: SidebarViewModel) -> some View {
    NewSessionSheet(
      initialMode: sidebarVM.newSessionInitialMode,
      topics: sheetTopics,
      bankQuestions: sheetBankQuestions,
      defaultProvider: chatService.globalPreferences?.chatProvider ?? .claude,
      specialization: chatService.interviewSettings.specialization,
      isModeSelectionLocked: sidebarVM.isNewSessionModeSelectionLocked,
      knowledgeLibrary: chatService.knowledgeLibrary,
      onStart: { request in
        sidebarVM.isNewSessionSheetPresented = false
        sidebarVM.preparePendingNewSession(
          mode: request.mode,
          provider: request.provider ?? chatService.globalPreferences?.chatProvider ?? .claude,
          workingDirectory: nil
        )
        sidebarVM.onStartSession?(request)
      },
      onCancel: {
        sidebarVM.isNewSessionSheetPresented = false
      }
    )
    .task {
      sheetTopics = (try? await chatService.interviewStorage.allTopics()) ?? []
      sheetBankQuestions = await chatService.questionBank.questions()
    }
  }

  private var leadingToolbarButtons: some View {
    Button(action: toggleSidebarPanel) {
      Label("Toggle sidebar", systemImage: "sidebar.left")
        .labelStyle(.iconOnly)
        .font(.system(size: 14, weight: .medium))
        .frame(width: 28, height: 28)
    }
    .buttonStyle(.plain)
    .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
    .help("Toggle Sidebar")
  }

  private func cyclePanelLayout() {
    var nextState = panelLayoutState
    nextState.advanceCommandShortcutCycle()
    setPanelLayoutState(nextState)
  }

  private func toggleSidebarPanel() {
    var nextState = panelLayoutState
    nextState.toggleSidebar()
    setPanelLayoutState(nextState)
  }

  private func toggleStudioFullWidth() {
    var nextState = panelLayoutState
    nextState.toggleCanvasFullWidth()
    setPanelLayoutState(nextState)
  }

  private func setPanelLayoutState(_ state: CanvasPanelLayoutState) {
    panelLayoutState = state
    sidebarViewModel?.isSidebarVisible = shouldShowSidebar
  }

  private var availableSurfaces: [StudioSurface] {
    StudioSurface.available(
      for: chatService.currentMode,
      includesSources: shouldExposeKnowledgeSources,
      includesLesson: chatService.isLearningSession
    )
  }

  /// The run strip belongs to a live drill only: a finished run is told in the
  /// report, and the other modes have a single problem to track.
  private var isDrillRunActive: Bool {
    chatService.currentMode == .drill &&
      chatService.interviewSession.activeAttempt?.status == .inProgress
  }

  private var shouldExposeKnowledgeSources: Bool {
    guard chatService.currentKnowledgeStudySpaceID != nil else {
      return false
    }
    return chatService.isLearningSession ||
      chatService.currentKnowledgeSourcesAreOpen ||
      chatService.interviewSession.activeAttempt?.status == .evaluated
  }

  private var studioSurfacePanel: some View {
    VStack(spacing: 0) {
      studioSurfaceTopBar

      Rectangle()
        .fill(.quaternary)
        .frame(height: 1)

      if isVoiceTranscriptPresented {
        CodingBuddyVoiceTranscriptStrip(
          controller: voiceController,
          onClose: hideVoiceTranscript
        )
        .transition(
          reduceMotion
            ? .opacity
            : .move(edge: .top).combined(with: .opacity)
        )

        Rectangle()
          .fill(.quaternary)
          .frame(height: 1)
      }

      if isDrillRunActive {
        DrillRunStripView(
          run: chatService.interviewSession.drillRun,
          nextDifficulty: chatService.interviewSession.suggestedNextDifficulty
        )

        Rectangle()
          .fill(.quaternary)
          .frame(height: 1)
      }

      // Same ZStack + opacity/hit-testing switching as Spar's canvas panel:
      // surfaces stay alive (editor buffers, whiteboard web view) while hidden.
      ZStack {
        if availableSurfaces.contains(.lesson) {
          LessonPanelView(
            chatService: chatService,
            onOpenLibrary: { isLessonLibraryPresented = true }
          )
          .opacity(selectedSurface == .lesson ? 1 : 0)
          .allowsHitTesting(selectedSurface == .lesson)
          .accessibilityHidden(selectedSurface != .lesson)
        }

        KnowledgeSourcesView(
          library: chatService.knowledgeLibrary,
          studySpaceID: chatService.currentKnowledgeStudySpaceID,
          isLocked: !shouldExposeKnowledgeSources
        )
        .opacity(selectedSurface == .sources ? 1 : 0)
        .allowsHitTesting(selectedSurface == .sources)
        .accessibilityHidden(selectedSurface != .sources)

        HintsView(
          question: chatService.interviewSession.activeQuestion,
          attempt: chatService.interviewSession.activeAttempt,
          mode: chatService.currentMode,
          hintsRemaining: chatService.interviewSession.hintsRemaining,
          onRequestHint: {
            chatService.requestHint()
          }
        )
        .opacity(selectedSurface == .hints ? 1 : 0)
        .allowsHitTesting(selectedSurface == .hints)
        .accessibilityHidden(selectedSurface != .hints)

        if availableSurfaces.contains(.workspace) {
          Group {
            if chatService.currentMode == .codingProject {
              CodingProjectRequirementsView(
                workspacePath: chatService.interviewSession.activeAttempt?.workspacePath,
                question: chatService.interviewSession.activeQuestion,
                externalRefreshToken: chatService.workspaceRevision
              )
            } else {
              WorkspaceEditorView(
                workspacePath: chatService.interviewSession.activeAttempt?.workspacePath,
                question: chatService.interviewSession.activeQuestion,
                externalRefreshToken: chatService.workspaceRevision,
                onReviewRequested: { fileName in
                  chatService.requestReview(fileName: fileName)
                },
                floatingAccessory: workspaceHintsAccessory
              )
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .opacity(selectedSurface == .workspace ? 1 : 0)
          .allowsHitTesting(selectedSurface == .workspace)
          .accessibilityHidden(selectedSurface != .workspace)
        }

        if availableSurfaces.contains(.whiteboard) {
          whiteboardSurface
            .opacity(selectedSurface == .whiteboard ? 1 : 0)
            .allowsHitTesting(selectedSurface == .whiteboard)
            .accessibilityHidden(selectedSurface != .whiteboard)
        }

        SessionReportView(
          evaluation: chatService.interviewSession.latestEvaluation,
          notes: chatService.interviewSession.latestNotes,
          attempt: chatService.interviewSession.activeAttempt,
          isGenerating: isReportGenerationRequested,
          drillRun: chatService.interviewSession.drillRun
        )
        .opacity(selectedSurface == .report ? 1 : 0)
        .allowsHitTesting(selectedSurface == .report)
        .accessibilityHidden(selectedSurface != .report)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $isLessonLibraryPresented) {
      knowledgeLibrarySheet
    }
    .onChange(of: chatService.currentMode) { _, _ in
      if !availableSurfaces.contains(selectedSurface) {
        selectedSurface = currentDefaultSurface
      }
    }
    .onChange(of: chatService.currentSessionId) { _, _ in
      isReportGenerationRequested = false
      isWhiteboardCreationRequested = false
      selectedSurface = currentDefaultSurface
      // Restored sessions with a report jump straight to it — but a learning
      // session never grades, so its lesson keeps the surface.
      if chatService.interviewSession.latestEvaluation != nil, !chatService.isLearningSession {
        selectedSurface = .report
      }
    }
    .onChange(of: chatService.currentKnowledgeStudySpaceID) { _, _ in
      if !availableSurfaces.contains(selectedSurface) {
        selectedSurface = currentDefaultSurface
      }
    }
    .onChange(of: chatService.knowledgeLibrary.citationActivationCount) { _, _ in
      // Only explicit transcript citation clicks reveal the Sources surface;
      // background browsing in the (hidden) panel must not steal the surface.
      if shouldExposeKnowledgeSources {
        selectedSurface = .sources
      }
    }
    .onChange(of: chatService.chatViewModel?.isLoading) { wasLoading, isLoading in
      if isWhiteboardCreationRequested,
         wasLoading == true,
         isLoading != true,
         chatService.currentMCPRenderItems.isEmpty {
        isWhiteboardCreationRequested = false
      }
    }
  }

  @ViewBuilder
  private var whiteboardSurface: some View {
    let items = chatService.currentMCPRenderItems
    if items.isEmpty {
      if chatService.currentMode == .systemDesign {
        // The kickoff turn creates the canvas, so "agent responding, no canvas
        // yet" reads as setup in progress rather than idle emptiness.
        SystemDesignWhiteboardEmptyView(
          isCreatingWhiteboard: isWhiteboardCreationRequested
            || chatService.chatViewModel?.isLoading == true,
          canCreateWhiteboard: chatService.canRequestWhiteboard,
          onCreateWhiteboard: createSystemDesignWhiteboard
        )
      } else {
        ContentUnavailableView {
          Label("Whiteboard", systemImage: "rectangle.3.group")
        } description: {
          Text("When \(AppBrand.name) draws on the shared whiteboard (via an MCP app like excalidraw), the diagram renders here.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
      }
    } else {
      MCPAppSidePanelView(
        items: items,
        host: chatService.mcpApps,
        onDismiss: {
          selectedSurface = currentDefaultSurface == .whiteboard
            ? .hints
            : currentDefaultSurface
        },
        isEmbedded: true
      )
      .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
      .overlay(alignment: .bottomTrailing) {
        whiteboardReviewButton
      }
    }
  }

  /// Sends the canvas (via its checkpoint) and any workspace code to the agent
  /// for a coaching review. Floats bottom-trailing, clear of Excalidraw's own
  /// bottom-leading zoom/undo controls.
  private var whiteboardReviewButton: some View {
    Button {
      chatService.requestWhiteboardReview()
    } label: {
      Label("Ask Agent to Review", systemImage: "bubble.left.and.text.bubble.right")
        .font(.system(size: 13, weight: .semibold))
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .disabled(!chatService.canRequestWhiteboardReview)
    .help("The agent re-reads the whiteboard and your workspace code, then gives interviewer-style feedback")
    .padding(16)
  }

  private var studioSurfaceTopBar: some View {
    HStack(spacing: 12) {
      Picker("Surface", selection: $selectedSurface) {
        ForEach(availableSurfaces) { surface in
          Label(
            surface.displayName(for: chatService.currentMode),
            systemImage: surface.systemImage(for: chatService.currentMode)
          )
            .tag(surface)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(
        width: CGFloat(availableSurfaces.count)
          * (chatService.currentMode == .codingProject ? 116 : 92)
      )

      Spacer()

      #if DEBUG
        if chatService.currentWorkingDirectory != nil {
          CanvasProjectTokenBadge(summary: chatService.currentWorkspaceUsageSummary)
        }
      #endif

      Button(action: toggleStudioFullWidth) {
        Label(studioWidthButtonTitle, systemImage: studioWidthButtonSystemImage)
          .font(.system(size: 13, weight: .medium))
          .labelStyle(.iconOnly)
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help(studioWidthButtonTitle)

      if let currentWorkingDirectory = chatService.currentWorkingDirectory {
        Label(URL(fileURLWithPath: currentWorkingDirectory).lastPathComponent, systemImage: "folder")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(currentWorkingDirectory)
      }

      if chatService.currentMode != nil,
         chatService.interviewSession.activeAttempt?.status == .inProgress {
        TimerPillView(
          timer: chatService.sessionTimer,
          onEndAndGrade: endAndGrade
        )
        .layoutPriority(1)
      }
    }
    .padding(.leading, studioToolbarLeadingPadding)
    .padding(.trailing, 16)
    .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
    .background(.regularMaterial)
  }

  private var chatToolbarLeadingPadding: CGFloat {
    panelLayoutState.showsSidebar ? EaselDesignSystem.Spacing.large : windowControlLeadingReserve
  }

  private var studioToolbarLeadingPadding: CGFloat {
    panelLayoutState.showsChatPanel ? 16 : windowControlLeadingReserve
  }

  private var workspaceHintsAccessory: AnyView? {
    guard selectedSurface == .workspace,
          let mode = chatService.currentMode,
          chatService.interviewSession.activeAttempt?.status == .inProgress else {
      return nil
    }

    return AnyView(
      FloatingHintsButton(
        question: chatService.interviewSession.activeQuestion,
        attempt: chatService.interviewSession.activeAttempt,
        mode: mode,
        hintsRemaining: chatService.interviewSession.hintsRemaining,
        onRequestHint: chatService.requestHint
      )
    )
  }

  private var studioWidthButtonTitle: String {
    panelLayoutState.isCanvasFullWidth ? "Restore Side Panels" : "Expand Panel Full Width"
  }

  private var currentDefaultSurface: StudioSurface {
    StudioSurface.defaultSurface(
      for: chatService.currentMode,
      isLearningSession: chatService.isLearningSession
    )
  }

  private var studioWidthButtonSystemImage: String {
    panelLayoutState.isCanvasFullWidth
      ? "arrow.down.right.and.arrow.up.left"
      : "arrow.up.left.and.arrow.down.right"
  }

  private func endAndGrade() {
    isReportGenerationRequested = true
    selectedSurface = .report
    Task {
      await chatService.endAndGrade()
    }
  }

  private func createSystemDesignWhiteboard() {
    isWhiteboardCreationRequested = chatService.requestWhiteboard()
  }

  private func handleVoiceStatusChange(
    _ status: CodingBuddyVoiceConversationStatus
  ) {
    if case .failed = status {
      setVoiceTranscriptPresented(true)
    } else if status == .connecting,
              voiceController.shouldAutomaticallyShowTranscript {
      setVoiceTranscriptPresented(true)
    } else if !status.isActive {
      setVoiceTranscriptPresented(false)
    }
  }

  private func hideVoiceTranscript() {
    setVoiceTranscriptPresented(false)
  }

  private func toggleVoiceTranscript() {
    setVoiceTranscriptPresented(!isVoiceTranscriptPresented)
  }

  private func setVoiceTranscriptPresented(_ isPresented: Bool) {
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
      isVoiceTranscriptPresented = isPresented
    }
  }

  private func dismissVoiceOnboarding() {
    isVoiceOnboardingPresented = false
  }
}

enum MainContentMode: Equatable {
  case dashboard
  case session

  mutating func showSession() {
    self = .session
  }

  mutating func toggleDashboard() {
    self = self == .dashboard ? .session : .dashboard
  }
}
