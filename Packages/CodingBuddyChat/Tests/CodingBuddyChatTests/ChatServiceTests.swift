//
//  ChatServiceTests.swift
//  CodingBuddyChatTests
//

import Foundation
import Testing
import ClaudeCodeCore
@testable import CodingBuddyChat

@MainActor
struct ChatServiceTests {

  @Test
  func initialState() {
    let service = ChatService()
    #expect(service.chatViewModel == nil)
    #expect(service.isInitialized == false)
    #expect(service.initError == nil)
    #expect(service.currentSessionId == nil)
  }

  @Test
  func sendMessageWithoutInitializationIsNoOp() {
    let service = ChatService()
    // Should not crash when chatViewModel is nil
    service.sendMessage("test")
  }

  @Test
  func switchingSessionsReusesIsolatedViewModels() async throws {
    let service = ChatService(sessionStorage: NoOpSessionStorage())
    await service.initialize()

    await service.switchToSession(storedSession(id: "session-a", workingDirectory: "/tmp/session-a", provider: .claude))
    let sessionAViewModel = try #require(service.chatViewModel)

    await service.switchToSession(storedSession(id: "session-b", workingDirectory: "/tmp/session-b", provider: .codex))
    let sessionBViewModel = try #require(service.chatViewModel)

    #expect(sessionAViewModel !== sessionBViewModel)

    await service.switchToSession(storedSession(id: "session-a", workingDirectory: "/tmp/session-a", provider: .claude))
    let restoredSessionAViewModel = try #require(service.chatViewModel)

    #expect(restoredSessionAViewModel === sessionAViewModel)
  }

  @Test
  func startingNewSessionDoesNotReuseCurrentSessionViewModel() async throws {
    let service = ChatService(sessionStorage: NoOpSessionStorage())
    await service.initialize()

    await service.switchToSession(storedSession(id: "session-a", workingDirectory: "/tmp/session-a", provider: .claude))
    let sessionAViewModel = try #require(service.chatViewModel)

    await service.startNewSession(workingDirectory: "/tmp/new-session")
    let newSessionViewModel = try #require(service.chatViewModel)

    #expect(newSessionViewModel !== sessionAViewModel)

    await service.switchToSession(storedSession(id: "session-a", workingDirectory: "/tmp/session-a", provider: .claude))
    let restoredSessionAViewModel = try #require(service.chatViewModel)

    #expect(restoredSessionAViewModel === sessionAViewModel)
  }

  @Test
  func clearingActiveWorkspaceDropsSessionState() async {
    let service = ChatService(sessionStorage: NoOpSessionStorage())
    await service.initialize()
    await service.startNewSession(workingDirectory: "/tmp/workspace")

    await service.clearActiveWorkspace()

    #expect(service.currentWorkingDirectory == nil)
    #expect(service.currentSessionId == nil)
  }

  private func storedSession(
    id: String,
    workingDirectory: String,
    provider: ChatProvider = .codex
  ) -> StoredSession {
    StoredSession(
      id: id,
      createdAt: Date.now,
      firstUserMessage: "Initial prompt",
      lastAccessedAt: Date.now,
      workingDirectory: workingDirectory,
      provider: provider
    )
  }
}
