//
//  MainContentView.swift
//  CodingBuddy
//

import BuddyMCPApps
import ClaudeCodeCore
import CodingBuddyChat
import CodingBuddyKit
import InterviewKit
import SwiftUI

struct MainContentView: View {
  @Bindable var appState: AppState
  let initialPrompt: String
  let chatService: ChatService

  @State private var sidebarViewModel: SidebarViewModel?
  @State private var panelLayoutState: CanvasPanelLayoutState = .allPanels
  @State private var didHandleInitialPrompt = false
  @State private var sheetTopics: [Topic] = []
  @State private var sheetBankQuestions: [Question] = []
  @State private var selectedSurface: StudioSurface = .workspace
  @State private var contentMode: MainContentMode = .session
  @Environment(\.colorScheme) private var colorScheme

  private let chatPanelWidth: CGFloat = 380
  private let sidebarWidth: CGFloat = 340
  private let windowControlLeadingReserve: CGFloat = 78

  var body: some View {
    HStack(spacing: 0) {
      if let sidebarVM = sidebarViewModel, shouldShowSidebar {
        SidebarView(
          sidebarViewModel: sidebarVM,
          reservesWindowControls: true,
          newSessionSheetProvider: { AnyView(newSessionSheet(for: sidebarVM)) }
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

              hintRequestButton
            }
            .padding(.leading, chatToolbarLeadingPadding)
            .padding(.trailing, EaselDesignSystem.Spacing.large)
            .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
            .background(EaselDesignSystem.Palette.surface(for: colorScheme))

            Rectangle()
              .fill(EaselDesignSystem.Palette.border(for: colorScheme))
              .frame(height: 1)

            ChatPanelView(chatService: chatService)
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
        Task {
          await chatService.initialize()
          await chatService.switchToSession(session)
          await vm.loadSessions()
        }
      }
      vm.onStartSession = { request in
        selectedSurface = StudioSurface.defaultSurface(for: request.mode)
        Task {
          await chatService.initialize()
          await chatService.startNewSession(request)
          await vm.loadSessions()
        }
      }
      chatService.onEvaluationRecorded = { _ in
        selectedSurface = .report
      }
      vm.onDashboardToggle = {
        contentMode = contentMode == .dashboard ? .session : .dashboard
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
  }

  private var shouldShowSidebar: Bool {
    panelLayoutState.showsSidebar
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
          contentMode = .session
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
          contentMode = .session
          selectedSurface = StudioSurface.defaultSurface(for: question.mode)
          let request = ChatService.NewSessionRequest(
            mode: question.mode,
            question: question,
            durationSeconds: question.mode.isTimedByDefault ? 35 * 60 : nil
          )
          sidebarViewModel?.preparePendingNewSession(mode: question.mode, workingDirectory: nil)
          sidebarViewModel?.onStartSession?(request)
        },
        onOpenSession: { chatSessionId in
          contentMode = .session
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
      onStart: { request in
        sidebarVM.isNewSessionSheetPresented = false
        sidebarVM.preparePendingNewSession(mode: request.mode, workingDirectory: nil)
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

  // Deterministic hint layer: coding modes only, disabled once the budget is
  // spent (free-typed hint asks still work, governed by the prompt).
  @ViewBuilder
  private var hintRequestButton: some View {
    if let mode = chatService.currentMode,
       mode == .mockInterview || mode == .drill || mode == .practice,
       chatService.interviewSession.activeAttempt?.status == .inProgress,
       let hintsRemaining = chatService.interviewSession.hintsRemaining {
      Button {
        chatService.requestHint()
      } label: {
        Label("Hint (\(hintsRemaining) left)", systemImage: "lightbulb")
          .font(.system(size: 12, weight: .medium))
          .labelStyle(.titleAndIcon)
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .disabled(hintsRemaining == 0)
      .help(hintsRemaining == 0 ? "Hint budget spent" : "Request a hint from the interviewer")
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
    StudioSurface.available(for: chatService.currentMode)
  }

  private var studioSurfacePanel: some View {
    VStack(spacing: 0) {
      studioSurfaceTopBar

      Rectangle()
        .fill(.quaternary)
        .frame(height: 1)

      // Same ZStack + opacity/hit-testing switching as Easel's canvas panel:
      // surfaces stay alive (editor buffers, whiteboard web view) while hidden.
      ZStack {
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
          WorkspaceEditorView(
            workspacePath: chatService.interviewSession.activeAttempt?.workspacePath,
            question: chatService.interviewSession.activeQuestion
          )
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
          attempt: chatService.interviewSession.activeAttempt
        )
        .opacity(selectedSurface == .report ? 1 : 0)
        .allowsHitTesting(selectedSurface == .report)
        .accessibilityHidden(selectedSurface != .report)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onChange(of: chatService.currentMode) { _, newMode in
      if !StudioSurface.available(for: newMode).contains(selectedSurface) {
        selectedSurface = StudioSurface.defaultSurface(for: newMode)
      }
    }
    .onChange(of: chatService.currentSessionId) { _, _ in
      selectedSurface = StudioSurface.defaultSurface(for: chatService.currentMode)
      // Restored sessions with a report jump straight to it.
      if chatService.interviewSession.latestEvaluation != nil {
        selectedSurface = .report
      }
    }
  }

  @ViewBuilder
  private var whiteboardSurface: some View {
    let items = chatService.currentMCPRenderItems
    if items.isEmpty {
      ContentUnavailableView {
        Label("Whiteboard", systemImage: "rectangle.3.group")
      } description: {
        Text("When Buddy draws on the shared whiteboard (via an MCP app like excalidraw), the diagram renders here.")
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    } else {
      MCPAppSidePanelView(
        items: items,
        host: chatService.mcpApps,
        onDismiss: {
          selectedSurface = StudioSurface.defaultSurface(for: chatService.currentMode) == .whiteboard
            ? .hints
            : StudioSurface.defaultSurface(for: chatService.currentMode)
        },
        isEmbedded: true
      )
      .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    }
  }

  private var studioSurfaceTopBar: some View {
    HStack(spacing: 12) {
      Picker("Surface", selection: $selectedSurface) {
        ForEach(availableSurfaces) { surface in
          Label(surface.displayName, systemImage: surface.systemImage)
            .tag(surface)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: CGFloat(availableSurfaces.count) * 92)

      Spacer()

      if let mode = chatService.currentMode,
         chatService.interviewSession.activeAttempt?.status == .inProgress {
        TimerPillView(
          timer: chatService.sessionTimer,
          mode: mode,
          onEndAndGrade: {
            selectedSurface = .report
            Task { await chatService.endAndGrade() }
          }
        )
      }

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

  private var studioWidthButtonTitle: String {
    panelLayoutState.isCanvasFullWidth ? "Restore Side Panels" : "Expand Panel Full Width"
  }

  private var studioWidthButtonSystemImage: String {
    panelLayoutState.isCanvasFullWidth
      ? "arrow.down.right.and.arrow.up.left"
      : "arrow.up.left.and.arrow.down.right"
  }
}

private enum MainContentMode: Equatable {
  case dashboard
  case session
}
