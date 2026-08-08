//
//  BuddyAgentInstructionsTests.swift
//  CodingBuddyChatTests
//

import Foundation
import InterviewKit
import KnowledgeKit
import Testing
@testable import CodingBuddyChat

struct BuddyAgentInstructionsTests {

  @Test
  func everyModeHasAllThreeProviderPrefixes() {
    for mode in SessionMode.allCases {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      #expect(!prefixes.claude.isEmpty)
      #expect(!prefixes.codex.isEmpty)
      #expect(!prefixes.api.isEmpty)
      // Full prompts carry both contracts; compact api variant carries fences.
      #expect(prefixes.claude.contains("buddy-question"))
      #expect(prefixes.claude.contains("buddy-eval"))
      #expect(prefixes.claude.contains("buddy-study-plan"))
      #expect(prefixes.api.contains("buddy-question"))
      #expect(prefixes.api.contains("buddy-eval"))
      #expect(prefixes.api.contains("buddy-study-plan"))
      #expect(!prefixes.claude.contains("\"verdict\""))
      #expect(!prefixes.api.contains("\"verdict\""))
      // Compact prompts stay small for local models.
      #expect(prefixes.api.count < prefixes.claude.count)
    }
  }

  @Test
  func mockInterviewPersonaEnforcesHintDiscipline() {
    let prefixes = BuddyAgentInstructions.prefixes(for: .mockInterview)
    #expect(prefixes.claude.contains("[HINT REQUEST]"))
    #expect(prefixes.claude.contains("never confirm correctness") || prefixes.claude.contains("never confirm"))
    #expect(prefixes.claude.contains("speed"))
  }

  @Test
  func knowledgeActivitiesAddProviderNeutralGroundingRules() {
    let learn = KnowledgeSessionConfiguration(
      studySpaceID: "space",
      activity: .learn
    )
    let closedBookInterview = KnowledgeSessionConfiguration(
      studySpaceID: "space",
      activity: .interview,
      sourceAccess: .closedBook
    )

    let learnPrefixes = BuddyAgentInstructions.prefixes(
      for: .practice,
      knowledgeConfiguration: learn
    )
    let interviewPrefixes = BuddyAgentInstructions.prefixes(
      for: .mockInterview,
      knowledgeConfiguration: closedBookInterview
    )

    // Every provider gets the lesson loop: the fence, the one-task-per-turn
    // rule, and the bans that the loose prose contract failed to enforce.
    for prompt in [learnPrefixes.claude, learnPrefixes.codex, learnPrefixes.api] {
      #expect(prompt.contains("Source-grounded learning session"))
      #expect(prompt.contains("untrusted"))
      #expect(prompt.contains("buddy-study-plan-state"))
      #expect(prompt.contains("[STUDY PLAN RANDOM]"))
      #expect(prompt.contains("[LESSON RESPONSE]"))
      #expect(prompt.contains("[LESSON STUCK]"))
      #expect(prompt.contains("buddy-lesson/v1"))
      #expect(prompt.contains("scenario_markdown"))
      #expect(prompt.contains("inspect_steps"))
      #expect(prompt.contains("reply_scaffold"))
      #expect(prompt.contains("item_complete"))
      #expect(prompt.contains("feedback_markdown"))
      #expect(prompt.contains("teaches_markdown"))
      #expect(prompt.contains("one task per turn"))
      #expect(prompt.contains("never ask the learner to invent a question") ||
              prompt.contains("Never ask the learner to invent"))
      #expect(prompt.contains("repeat a fact you just stated") ||
              prompt.contains("repeat a\nfilename") ||
              prompt.contains("Never ask them to repeat a"))
      #expect(prompt.contains("No long articles") ||
              prompt.contains("never as an article"))
    }
    // The learn prompts stay agent-led — the old "suggest a question for the
    // user to ask" phrasing is what produced the aimless sessions.
    #expect(learnPrefixes.claude.contains("Be agent-led"))
    #expect(!learnPrefixes.claude.contains("check-for-understanding"))
    // Compact stays compact even carrying the new contract.
    #expect(learnPrefixes.api.count < learnPrefixes.claude.count)
    for prompt in [interviewPrefixes.claude, interviewPrefixes.codex, interviewPrefixes.api] {
      #expect(prompt.contains("Source-grounded interview session"))
      #expect(prompt.contains("closed book"))
      #expect(prompt.contains("do not reveal source citations"))
    }
  }

  @Test
  func studyPlanDirectivesUseTheProviderNeutralContract() {
    let directive = BuddyAgentInstructions.studyPlanGenerationDirective(
      studySpaceName: "CodingBuddy",
      requestedItemID: "session-flow"
    )
    #expect(directive.contains("[CREATE STUDY PLAN]"))
    #expect(directive.contains("buddy-study-plan/v1"))
    #expect(directive.contains("session-flow"))
    #expect(directive.contains("Do not create or update any plan file"))
    #expect(directive.contains("separate Practice session"))
    #expect(!directive.contains("begin its first item"))

    #expect(BuddyAgentInstructions.studyPlanRepairDirective().contains("buddy-study-plan"))
    let topicRequest = BuddyAgentInstructions.studyTopicRequestMessage(
      itemID: "storage",
      title: "Understand Storage",
      itemNumber: 1,
      totalItemCount: 12
    )
    #expect(topicRequest.hasPrefix("Start Item 1 of 12: “Understand Storage”."))
    #expect(topicRequest.contains("[STUDY PLAN ITEM: storage]"))
    #expect(topicRequest.contains("buddy-lesson"))
    #expect(topicRequest.contains("step 1"))
    #expect(topicRequest.contains("Do not ask me to invent a question"))
    #expect(topicRequest.contains("wait for my response"))
    #expect(BuddyAgentInstructions.randomStudyTopicMessage.contains("[STUDY PLAN RANDOM]"))
    #expect(BuddyAgentInstructions.nextStudyTopicMessage.contains("buddy-lesson"))
  }

  @Test
  func lessonTurnMessagesDriveTheLoopWithoutRevealingAnswers() {
    let response = BuddyAgentInstructions.lessonResponseMessage(
      "  Note: the buffer is flushed on a terminal event.  "
    )
    #expect(response.hasPrefix("[LESSON RESPONSE]"))
    #expect(response.contains("Note: the buffer is flushed on a terminal event."))
    // The marker must not be padded with the learner's stray whitespace.
    #expect(!response.hasSuffix(" "))

    let stuck = BuddyAgentInstructions.lessonStuckMessage
    #expect(stuck.contains("[LESSON STUCK]"))
    #expect(stuck.contains("Do not answer it for me"))
    #expect(stuck.contains("same step"))

    let repair = BuddyAgentInstructions.lessonRepairDirective()
    #expect(repair.contains("[LESSON PARSE ERROR]"))
    #expect(repair.contains("buddy-lesson/v1"))
    #expect(repair.contains("inspect_steps"))
  }

  @Test
  func lessonContractIsScopedToLearningSessions() {
    // The lesson loop only ships with a learn-activity session: a plain
    // interview prompt must not carry a contract it can never satisfy.
    let plain = BuddyAgentInstructions.prefixes(for: .practice)
    let interview = BuddyAgentInstructions.prefixes(
      for: .mockInterview,
      knowledgeConfiguration: KnowledgeSessionConfiguration(
        studySpaceID: "space",
        activity: .interview
      )
    )

    for prompt in [plain.claude, plain.api, interview.claude, interview.api] {
      #expect(!prompt.contains("buddy-lesson"))
    }
  }

  @Test
  func systemDesignPersonaMentionsWhiteboard() {
    let prefixes = BuddyAgentInstructions.prefixes(for: .systemDesign)
    #expect(prefixes.claude.contains("excalidraw"))
    #expect(prefixes.claude.contains("scalability_tradeoffs"))
    #expect(prefixes.claude.contains("[CREATE WHITEBOARD]"))
    #expect(prefixes.codex.contains("[CREATE WHITEBOARD]"))
    #expect(prefixes.api.contains("[CREATE WHITEBOARD]"))
    #expect(BuddyAgentInstructions.whiteboardRequestMessage.contains("[CREATE WHITEBOARD]"))
  }

  @Test
  func hiddenContextCarriesTimerHintsAndWorkspace() {
    let attempt = InterviewAttempt(
      provider: "claude",
      mode: .mockInterview,
      startedAt: Date(),
      plannedDurationSeconds: 2100,
      hintBudget: 3,
      hintsUsed: 1,
      workspacePath: "/Users/x/Documents/CodingBuddy/Workspaces/2026-07-31-longest-substring"
    )
    let question = Question(
      mode: .mockInterview,
      title: "Longest Substring Without Repeating Characters",
      promptMarkdown: "…",
      difficulty: .medium,
      topicIds: ["sliding-window"]
    )

    let context = BuddyAgentInstructions.appendingHiddenContext(
      nil,
      attempt: attempt,
      question: question,
      timerRemaining: 1294,
      phase: .inProgress
    )

    #expect(context.contains("<buddy-context>"))
    #expect(context.contains("mode: mock_interview | phase: in_progress"))
    #expect(context.contains("\"Longest Substring Without Repeating Characters\""))
    #expect(context.contains("(medium; sliding-window)"))
    #expect(context.contains("timer: 21:34 remaining of 35:00"))
    #expect(context.contains("hints: 1 used of 3"))
    #expect(context.contains("workspace: /Users/x/Documents/CodingBuddy/Workspaces/2026-07-31-longest-substring"))
  }

  @Test
  func awaitingEvaluationSuppressesTimerLine() {
    let attempt = InterviewAttempt(
      provider: "claude",
      mode: .drill,
      plannedDurationSeconds: 1200,
      hintBudget: 3
    )
    let context = BuddyAgentInstructions.appendingHiddenContext(
      nil,
      attempt: attempt,
      question: nil,
      timerRemaining: 600,
      phase: .awaitingEvaluation
    )
    #expect(!context.contains("timer:"))
    #expect(context.contains("phase: awaiting_evaluation"))
  }

  @Test
  func noAttemptPassesThroughHiddenContext() {
    let context = BuddyAgentInstructions.appendingHiddenContext(
      "extra",
      attempt: nil,
      question: nil,
      timerRemaining: nil,
      phase: .inProgress
    )
    #expect(context == "extra")
  }

  @Test
  func reviewContractCoachesWithoutRevealingSolutions() {
    for mode in SessionMode.allCases {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      // Full and compact prompts both carry the review trigger and the
      // never-reveal rule.
      #expect(prefixes.claude.contains("[REVIEW MY SOLUTION]"))
      #expect(prefixes.api.contains("[REVIEW MY SOLUTION]"))
      #expect(prefixes.claude.contains("NEVER provide the corrected code"))
    }

    let withFile = BuddyAgentInstructions.reviewRequestMessage(fileName: "solution.swift")
    #expect(withFile.contains("[REVIEW MY SOLUTION]"))
    #expect(withFile.contains("solution.swift"))

    let withoutFile = BuddyAgentInstructions.reviewRequestMessage(fileName: nil)
    #expect(withoutFile.contains("[REVIEW MY SOLUTION]"))
  }

  @Test
  func iOSSpecializationFlavorsEveryModeWithoutBreakingContracts() {
    for mode in SessionMode.allCases {
      let ios = BuddyAgentInstructions.prefixes(for: mode, specialization: .iOS)
      let general = BuddyAgentInstructions.prefixes(for: mode, specialization: .general)

      // iOS guidance lands in both the full and compact prompts.
      #expect(ios.claude.contains("Specialization:"))
      #expect(ios.api.contains("iOS track:"))
      // The general track keeps the classic un-slanted prompts.
      #expect(!general.claude.contains("Specialization:"))
      #expect(!general.api.contains("iOS track:"))
      // Contracts and the local-model size invariant survive the insert.
      #expect(ios.claude.contains("buddy-question"))
      #expect(ios.claude.contains("buddy-eval"))
      #expect(ios.api.count < ios.claude.count)
    }
  }

  @Test
  func specializationDefaultsToiOS() {
    let implicit = BuddyAgentInstructions.prefixes(for: .mockInterview)
    let explicit = BuddyAgentInstructions.prefixes(for: .mockInterview, specialization: .iOS)
    #expect(implicit.claude == explicit.claude)
    #expect(implicit.api == explicit.api)
    #expect(InterviewSpecialization.default == .iOS)
  }

  @Test
  func evaluationDirectiveCarriesSpecializationGuidance() {
    let ios = BuddyAgentInstructions.evaluationDirective(mode: .mockInterview, specialization: .iOS)
    #expect(ios.contains("[EVALUATE NOW]"))
    #expect(ios.contains("iOS role"))

    let general = BuddyAgentInstructions.evaluationDirective(mode: .mockInterview, specialization: .general)
    #expect(general.contains("[EVALUATE NOW]"))
    #expect(!general.contains("iOS role"))
  }

  @Test
  func evaluationDirectiveNamesModeRubric() {
    let directive = BuddyAgentInstructions.evaluationDirective(mode: .behavioral)
    #expect(directive.contains("[EVALUATE NOW]"))
    #expect(directive.contains("star_structure"))
    #expect(directive.contains("buddy-eval"))
    #expect(!directive.contains("\"verdict\""))

    let repair = BuddyAgentInstructions.evaluationRepairDirective()
    #expect(repair.contains("buddy-eval"))
    #expect(!repair.contains("\"verdict\""))
  }
}
