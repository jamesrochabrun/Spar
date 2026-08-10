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
      // Compact prompts stay small for local models.
      #expect(prefixes.api.count < prefixes.claude.count)
    }

    // The retired buddy-eval "verdict" field must not creep back in. Drills
    // legitimately use the word for a per-rep buddy-rep verdict, so the ban
    // belongs to the evaluation contract rather than the whole prompt.
    #expect(!BuddyAgentInstructions.evalContract.contains("\"verdict\""))
    for mode in SessionMode.allCases where mode != .drill {
      #expect(!BuddyAgentInstructions.prefixes(for: mode).claude.contains("\"verdict\""))
      #expect(!BuddyAgentInstructions.prefixes(for: mode).api.contains("\"verdict\""))
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
  func questionPromptsRequireSelfContainedTypesForEveryProvider() {
    for mode in SessionMode.allCases {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      for prompt in [prefixes.claude, prefixes.codex, prefixes.api] {
        #expect(prompt.contains("prompt_markdown"))
        #expect(prompt.contains("self-contained"))
        #expect(prompt.contains("custom type"))
        #expect(prompt.contains("missing") && prompt.contains("scaffolding"))
      }
    }
  }

  @Test
  func everyProviderRequiresCleanCompilableWorkspaceSource() {
    for mode in SessionMode.allCases {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      for prompt in [prefixes.claude, prefixes.codex, prefixes.api] {
        #expect(prompt.contains("starter file"))
        #expect(prompt.contains("compiles before"))
        #expect(prompt.contains("Markdown fences"))
        #expect(prompt.contains("commented-out") || prompt.contains("comment out"))
        #expect(prompt.contains("indentation"))
        #expect(prompt.contains("2 spaces"))
      }
    }
  }

  @Test
  func evaluationPromptsGradeReasoningAndIgnoreSyntaxEntirely() {
    for mode in SessionMode.allCases {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      for prompt in [prefixes.claude, prefixes.codex, prefixes.api] {
        #expect(prompt.contains("editing process"))
        #expect(prompt.contains("thinking, not typing") || prompt.contains("Grade thinking, not typing"))
        #expect(prompt.contains("Ignore syntax entirely") || prompt.contains("Never score syntax"))
        #expect(prompt.contains("missing imports"))
        #expect(prompt.contains("boilerplate"))
      }

      let directive = BuddyAgentInstructions.evaluationDirective(mode: mode)
      #expect(directive.contains("editing process"))
      #expect(directive.contains("Syntax is out of scope"))
      #expect(directive.contains("Never score syntax"))
      #expect(directive.contains("scaffolding that you supplied"))
      // The old policy — "consider syntax if the final code would not compile"
      // — is exactly the nitpicking this rubric is meant to stop.
      #expect(!directive.contains("would not compile"))
    }
  }

  @Test
  func everyProviderPromptPutsBoilerplateAndSyntaxOnBuddy() {
    for mode in SessionMode.allCases {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      for prompt in [prefixes.claude, prefixes.codex, prefixes.api] {
        // Buddy writes the mechanical code, including test scaffolding.
        #expect(prompt.contains("XCTestCase") || prompt.contains("`XCTestCase`"))
        #expect(prompt.contains("@Suite"))
        #expect(prompt.contains("Xcode template") || prompt.contains("Xcode file template"))
        // Syntax help is free — it never spends the hint budget.
        #expect(prompt.contains("never counts as a hint") ||
                prompt.contains("NEVER consumes the hint budget"))
        // Only the assessed part stays withheld.
        #expect(prompt.contains("the approach"))
      }
    }
  }

  @Test
  func everyProviderImplementsAnExplicitlyRequestedFullSolution() {
    for mode in SessionMode.allCases {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      for prompt in [prefixes.claude, prefixes.codex, prefixes.api] {
        #expect(prompt.contains("implement the full solution"))
        #expect(prompt.contains("inspect the workspace"))
        #expect(prompt.contains("add or update relevant tests"))
        #expect(prompt.contains("verify"))
        #expect(prompt.contains("Do not infer"))
      }
    }
  }

  @Test
  func rubricsWeighReasoningInsteadOfCodeQuality() {
    let reasoningModes: [SessionMode] = [.mockInterview, .practice, .drill]
    for mode in reasoningModes {
      let directive = BuddyAgentInstructions.evaluationDirective(mode: mode)
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      for text in [directive, prefixes.claude, prefixes.api] {
        #expect(text.contains("reasoning"))
        #expect(!text.contains("code_quality"))
      }
    }
    // Non-coding rubrics keep their own dimensions.
    #expect(BuddyAgentInstructions.evaluationDirective(mode: .systemDesign)
      .contains("scalability_tradeoffs"))
    #expect(BuddyAgentInstructions.evaluationDirective(mode: .behavioral)
      .contains("star_structure"))
  }

  @Test
  func questionContractShipsTestScaffoldingInsteadOfDemandingIt() {
    for mode in SessionMode.allCases {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      for prompt in [prefixes.claude, prefixes.api] {
        #expect(prompt.contains("test file"))
        #expect(prompt.contains("example test") || prompt.contains("worked example test"))
      }
    }
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
  func drillHiddenContextCarriesTheRunAndTheDifficultyLadder() {
    let attempt = InterviewAttempt(
      provider: "claude",
      mode: .drill,
      plannedDurationSeconds: 1200,
      hintBudget: 3
    )

    var run = DrillRun()
    run.append(DrillRep(index: 1, topicIds: ["hash-maps"], difficulty: .easy, verdict: .incorrect))
    run.append(DrillRep(index: 2, topicIds: ["two-pointers"], difficulty: .easy, verdict: .correct))
    run.append(DrillRep(index: 3, topicIds: ["arrays"], difficulty: .medium, verdict: .correct))

    let context = BuddyAgentInstructions.appendingHiddenContext(
      nil,
      attempt: attempt,
      question: nil,
      timerRemaining: 600,
      phase: .inProgress,
      drillRun: run,
      suggestedDifficulty: .hard
    )

    #expect(context.contains("drill run: rep 4 | 2 clean, 0 partial, 1 missed of 3 | streak 2"))
    #expect(context.contains("recent reps: 1 incorrect (easy; hash-maps)"))
    #expect(context.contains("3 correct (medium; arrays)"))
    #expect(context.contains("revisit topics: hash-maps"))
    #expect(context.contains("next difficulty: hard"))
  }

  @Test
  func drillHiddenContextAnnouncesAnUngradedRun() {
    let attempt = InterviewAttempt(provider: "claude", mode: .drill, hintBudget: 3)
    let context = BuddyAgentInstructions.appendingHiddenContext(
      nil,
      attempt: attempt,
      question: nil,
      timerRemaining: nil,
      phase: .inProgress,
      suggestedDifficulty: .medium
    )
    #expect(context.contains("drill run: rep 1 — no reps graded yet"))
    #expect(context.contains("next difficulty: medium"))
    #expect(!context.contains("recent reps:"))
  }

  @Test
  func nonDrillModesNeverCarryRunLines() {
    var run = DrillRun()
    run.append(DrillRep(index: 1, verdict: .correct))

    for mode in SessionMode.allCases where mode != .drill {
      let attempt = InterviewAttempt(provider: "claude", mode: mode, hintBudget: 3)
      let context = BuddyAgentInstructions.appendingHiddenContext(
        nil,
        attempt: attempt,
        question: nil,
        timerRemaining: nil,
        phase: .inProgress,
        drillRun: run,
        suggestedDifficulty: .hard
      )
      #expect(!context.contains("drill run:"))
      #expect(!context.contains("next difficulty:"))
    }
  }

  @Test
  func drillPromptsCarryTheRepContractAndDeferTheLadderToTheApp() {
    let drill = BuddyAgentInstructions.prefixes(for: .drill)
    for prompt in [drill.claude, drill.codex, drill.api] {
      #expect(prompt.contains("buddy-rep"))
      #expect(prompt.contains("\"verdict\":\"correct|partial|incorrect\""))
      #expect(prompt.contains("next difficulty"))
      // The verdict follows the same reasoning-over-syntax rule as grading.
      #expect(prompt.contains("typo"))
    }
    // The old prompt claimed to read "recent scores from hidden context" that
    // the app never sent; the run lines replace it.
    #expect(!drill.claude.contains("recent scores"))

    // The rep contract is drill-only — no other mode can satisfy it.
    for mode in SessionMode.allCases where mode != .drill {
      let prefixes = BuddyAgentInstructions.prefixes(for: mode)
      #expect(!prefixes.claude.contains("buddy-rep"))
      #expect(!prefixes.api.contains("buddy-rep"))
    }
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
