//
//  MainContentView.swift
//  CodingBuddy
//

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
  @Environment(\.colorScheme) private var colorScheme

  private let chatPanelWidth: CGFloat = 380
  private let sidebarWidth: CGFloat = 340
  private let windowControlLeadingReserve: CGFloat = 78

  var body: some View {
    HStack(spacing: 0) {
      if let sidebarVM = sidebarViewModel, shouldShowSidebar {
        SidebarView(sidebarViewModel: sidebarVM, reservesWindowControls: true)
          .frame(width: sidebarWidth)
          .frame(maxHeight: .infinity)
          .transition(.move(edge: .leading))

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(width: 1)
      }

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
      let vm = SidebarViewModel(sessionStorage: chatService.sessionStorage)
      vm.onSessionSelected = { session in
        Task {
          await chatService.initialize()
          await chatService.switchToSession(session)
          await vm.loadSessions()
        }
      }
      vm.onNewChatRequested = { workingDirectory in
        Task {
          await chatService.initialize()
          await chatService.startNewSession(workingDirectory: workingDirectory)
          await vm.loadSessions()
        }
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

  // Placeholder right panel. Interview surfaces (problem, workspace,
  // whiteboard, report) land here in WP6/WP7.
  private var studioSurfacePanel: some View {
    VStack(spacing: 0) {
      studioSurfaceTopBar

      Rectangle()
        .fill(.quaternary)
        .frame(height: 1)

      ContentUnavailableView {
        Label("CodingBuddy", systemImage: "graduationcap")
      } description: {
        Text("Start a session to begin practicing.")
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var studioSurfaceTopBar: some View {
    HStack(spacing: 12) {
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
