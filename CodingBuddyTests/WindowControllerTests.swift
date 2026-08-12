//
//  WindowControllerTests.swift
//  CodingBuddyTests
//

import AppKit
import CodingBuddyChat
import CodingBuddyKit
import Testing
@testable import CodingBuddy

@MainActor
struct WindowControllerTests {

  @Test
  func capsuleUsesPanelAndCanvasUsesNativeWindow() {
    let appState = AppState()
    let controller = makeWindowController(
      appState: appState,
      isFloatingChatBarEnabled: true
    )

    #expect(controller.capsulePanel.styleMask.contains(.nonactivatingPanel))
    #expect(controller.capsulePanel.level == .floating)
    #expect(controller.canvasWindow.styleMask.contains(.titled))
    #expect(controller.canvasWindow.styleMask.contains(.closable))
    #expect(controller.canvasWindow.styleMask.contains(.miniaturizable))
    #expect(controller.canvasWindow.styleMask.contains(.resizable))
    #expect(controller.canvasWindow.styleMask.contains(.fullSizeContentView))
    #expect(!controller.canvasWindow.styleMask.contains(.nonactivatingPanel))
    #expect(controller.canvasWindow.title == AppBrand.name)
    #expect(controller.canvasWindow.titleVisibility == .hidden)
    #expect(controller.canvasWindow.titlebarAppearsTransparent)
    #expect(controller.canvasWindow.isMovableByWindowBackground)
    #expect(controller.canvasWindow.delegate === controller)
    #expect(!controller.canvasWindow.isReleasedWhenClosed)
  }

  @Test
  func closingCanvasWindowReturnsToCapsuleWithoutClosingWindow() {
    let appState = AppState()
    appState.phase = .canvas
    let controller = makeWindowController(
      appState: appState,
      isFloatingChatBarEnabled: true
    )

    let shouldClose = controller.windowShouldClose(controller.canvasWindow)

    #expect(!shouldClose)
    #expect(appState.phase == .capsule)
  }

  @Test
  func hideCapsuleOrdersOutPanel() {
    let appState = AppState()
    let controller = makeWindowController(
      appState: appState,
      isFloatingChatBarEnabled: true
    )
    controller.showCapsule()
    #expect(controller.capsulePanel.isVisible)

    controller.hideCapsule()
    #expect(!controller.capsulePanel.isVisible)
  }

  @Test
  func showCanvasOrdersOutCapsuleAndShowsCanvasWindow() {
    let appState = AppState()
    let controller = makeWindowController(
      appState: appState,
      isFloatingChatBarEnabled: true
    )
    defer {
      controller.canvasWindow.orderOut(nil)
      controller.capsulePanel.orderOut(nil)
    }
    controller.showCapsule()
    #expect(controller.capsulePanel.isVisible)

    controller.showCanvas()

    #expect(!controller.capsulePanel.isVisible)
    #expect(controller.canvasWindow.isVisible)
    #expect(controller.canvasWindow.contentView != nil)
    #expect(controller.canvasWindow.alphaValue == 1)
  }

  @Test
  func showCapsuleFallsBackToCanvasWhenFloatingChatBarIsDisabled() {
    let appState = AppState()
    let controller = makeWindowController(appState: appState)
    defer {
      controller.canvasWindow.orderOut(nil)
      controller.capsulePanel.orderOut(nil)
    }

    controller.showCapsule()

    #expect(appState.phase == .canvas)
    #expect(!controller.capsulePanel.isVisible)
    #expect(controller.canvasWindow.isVisible)
  }

  @Test
  func closingCanvasWindowDoesNotReturnToCapsuleWhenFloatingChatBarIsDisabled() {
    let appState = AppState()
    appState.phase = .canvas
    let controller = makeWindowController(appState: appState)

    let shouldClose = controller.windowShouldClose(controller.canvasWindow)

    #expect(shouldClose)
    #expect(appState.phase == .canvas)
  }

  @Test
  func canvasContentUsesSubmittedPromptSnapshot() {
    let appState = AppState()
    appState.promptText = "Build a dashboard"

    let chatService = ChatService()
    let view = MainContentView(
      appState: appState,
      initialPrompt: appState.promptText,
      chatService: chatService,
      voiceController: CodingBuddyVoiceController(session: chatService)
    )
    appState.promptText = "Edited later"

    #expect(view.initialPrompt == "Build a dashboard")
  }

  private func makeWindowController(
    appState: AppState,
    isFloatingChatBarEnabled: Bool = false
  ) -> WindowController {
    let chatService = ChatService()
    return WindowController(
      appState: appState,
      chatService: chatService,
      voiceController: CodingBuddyVoiceController(session: chatService),
      isFloatingChatBarEnabled: isFloatingChatBarEnabled,
      observesPhaseChanges: false
    )
  }
}
