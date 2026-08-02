//
//  BuddyAgentInstructionsTests.swift
//  CodingBuddyChatTests
//

import Foundation
import InterviewKit
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
      #expect(prefixes.api.contains("buddy-question"))
      #expect(prefixes.api.contains("buddy-eval"))
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
  func systemDesignPersonaMentionsWhiteboard() {
    let prefixes = BuddyAgentInstructions.prefixes(for: .systemDesign)
    #expect(prefixes.claude.contains("excalidraw"))
    #expect(prefixes.claude.contains("scalability_tradeoffs"))
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
  func evaluationDirectiveNamesModeRubric() {
    let directive = BuddyAgentInstructions.evaluationDirective(mode: .behavioral)
    #expect(directive.contains("[EVALUATE NOW]"))
    #expect(directive.contains("star_structure"))
    #expect(directive.contains("buddy-eval"))

    let repair = BuddyAgentInstructions.evaluationRepairDirective()
    #expect(repair.contains("buddy-eval"))
  }
}
