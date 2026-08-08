//
//  ChatServiceTests.swift
//  CodingBuddyChatTests
//

import ClaudeCodeCore
import Foundation
import KnowledgeKit
import Testing
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

  @Test
  func learningLibrarySelectionStartsFreshSessionWhenRequested() {
    let configuration = KnowledgeSessionConfiguration(
      studySpaceID: "clean-app",
      activity: .learn
    )

    #expect(ChatService.shouldReuseLearningSession(
      currentConfiguration: configuration,
      requestedStudySpaceID: "clean-app",
      hasPlan: true,
      startsNewSession: false
    ))
    #expect(!ChatService.shouldReuseLearningSession(
      currentConfiguration: configuration,
      requestedStudySpaceID: "clean-app",
      hasPlan: true,
      startsNewSession: true
    ))
  }

  @Test
  func lessonResolutionBackfillsWhatTheAgentOmitted() {
    let plan = studyPlan()
    let lesson = Lesson(itemID: "", step: 1, totalSteps: 3, outcome: "Explain the flow.")

    let resolved = ChatService.resolveLesson(
      lesson,
      requestedItemID: "session-flow",
      plan: plan
    )

    #expect(resolved.itemID == "session-flow")
    #expect(resolved.itemTitle == "Trace a session")
    // Everything the fence did carry survives untouched.
    #expect(resolved.outcome == "Explain the flow.")
    #expect(resolved.totalSteps == 3)
  }

  @Test
  func lessonResolutionKeepsCompletionAttachedToTheRequestedItem() {
    let plan = studyPlan()
    // The agent invented an id that isn't in the saved plan — trusting it would
    // point the "mark complete" button at nothing.
    let lesson = Lesson(itemID: "some-hallucinated-id", itemTitle: "Whatever")

    let resolved = ChatService.resolveLesson(
      lesson,
      requestedItemID: "storage",
      plan: plan
    )

    #expect(resolved.itemID == "storage")
    // A title the agent supplied is not overwritten — only a missing one is filled.
    #expect(resolved.itemTitle == "Whatever")
  }

  @Test
  func lessonResolutionPrefersTheAgentsItemWhenThePlanHasIt() {
    let plan = studyPlan()
    // A [STUDY PLAN NEXT] turn lets the agent pick, so its id wins when valid.
    let resolved = ChatService.resolveLesson(
      Lesson(itemID: "storage"),
      requestedItemID: nil,
      plan: plan
    )

    #expect(resolved.itemID == "storage")
    #expect(resolved.itemTitle == "Understand storage")
  }

  @Test
  func lessonResolutionSurvivesAMissingPlan() {
    let resolved = ChatService.resolveLesson(
      Lesson(itemID: "storage", itemTitle: "Understand storage"),
      requestedItemID: "storage",
      plan: nil
    )

    #expect(resolved.itemID == "storage")
    #expect(resolved.itemTitle == "Understand storage")
  }

  private func studyPlan() -> StudyPlan {
    StudyPlan(
      id: "study-plan-space",
      studySpaceID: "space",
      title: "Learn the app",
      summary: "",
      items: [
        StudyPlanItem(
          id: "session-flow",
          section: "Foundations",
          title: "Trace a session",
          objective: "Explain session creation."
        ),
        StudyPlanItem(
          id: "storage",
          section: "Persistence",
          title: "Understand storage",
          objective: "Explain the schemas."
        ),
      ]
    )
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
