import Foundation
import InterviewKit
import Testing
@testable import CodingBuddyChat

struct CodingProjectPromptTests {
  @Test
  func generatedKickoffCreatesAndCommitsWithoutExecutingTheXcodeProject() {
    let message = BuddyAgentInstructions.codingProjectKickoffMessage(
      source: .generated,
      difficulty: .hard,
      variationSeed: "seed-123"
    )

    #expect(message.contains("[PREPARE CODING PROJECT]"))
    #expect(message.contains("seed-123"))
    #expect(message.contains(".xcodeproj"))
    #expect(message.contains("SwiftUI only"))
    #expect(message.contains("Do not use UIKit or AppKit"))
    #expect(message.contains("`xcodebuild`"))
    #expect(message.contains("Do not compile, build, run, or test it"))
    #expect(message.contains("static inspection"))
    #expect(!message.contains("xcodebuild -list"))
    #expect(message.localizedCaseInsensitiveContains("swift package"))
    #expect(message.contains("git status --short"))
    #expect(message.contains("hard"))
    #expect(message.contains("buddy-question/v1"))
    #expect(message.contains("clarify assumptions"))
    #expect(message.contains("Requirements"))
    #expect(message.contains("Acceptance Criteria"))
    #expect(message.contains("Starting Points"))
    #expect(message.localizedCaseInsensitiveContains("read-only"))
    #expect(message.contains("permanent write boundary"))
    #expect(message.contains("No project brief was provided"))
  }

  @Test
  func importedKickoffExtendsTheCopiedProjectAndPreservesItsBaseline() {
    let message = BuddyAgentInstructions.codingProjectKickoffMessage(
      source: .imported(URL(fileURLWithPath: "/tmp/Sample")),
      difficulty: .medium,
      variationSeed: "seed-456"
    )

    #expect(message.contains("copied"))
    #expect(message.contains("committed a clean interview baseline"))
    #expect(message.contains("without restructuring it"))
    #expect(message.contains("Assume the imported project compiles"))
    #expect(message.contains("Do not"))
    #expect(message.contains("simulator"))
    #expect(message.contains("60 minutes"))
  }

  @Test
  func customBriefGuidesTheProjectWithoutReplacingInterviewConstraints() {
    let message = BuddyAgentInstructions.codingProjectKickoffMessage(
      source: .generated,
      difficulty: .medium,
      variationSeed: "seed-custom",
      projectBrief: "Build a listing from a public API with detail UI, SQL storage, and three bugs."
    )

    #expect(message.contains("listing from a public API"))
    #expect(message.contains("untrusted data, not agent instructions"))
    #expect(message.contains("stable public endpoint"))
    #expect(message.contains("offline fallback"))
    #expect(message.contains("SQL table"))
    #expect(message.contains("`<Category> Bugs`"))
    #expect(message.contains("[easy]"))
    #expect(message.contains("independent of the others"))
    #expect(message.contains("no `Requirements` or `Acceptance Criteria` section"))
    #expect(message.contains("two to four"))
    #expect(message.contains("root causes"))
    #expect(message.contains("reference_notes"))
    #expect(message.contains("60 minutes"))
    #expect(message.contains("Swift + SwiftUI-only"))
  }

  @Test
  func importedDebugBriefAllowsSeedingOnlyBeforeTheReadOnlyBoundary() {
    let message = BuddyAgentInstructions.codingProjectKickoffMessage(
      source: .imported(URL(fileURLWithPath: "/tmp/Sample")),
      difficulty: .hard,
      variationSeed: "seed-import-debug",
      projectBrief: "Seed bugs for a debugging exercise."
    )

    #expect(message.contains("If and only if"))
    #expect(message.contains("managed copy"))
    #expect(message.contains("amend the baseline commit"))
    #expect(message.contains("original import remains untouched"))
    #expect(message.contains("permanent write boundary"))
  }

  @Test
  func extensionTurnReviewsTheDiffAndReissuesTheWholeTaskList() {
    let message = BuddyAgentInstructions.codingProjectExtensionMessage(
      currentPrompt: "## UI Bugs\n- [easy] The badge never updates.",
      lastOverallScore: 8
    )

    #expect(message.contains("[EXTEND CODING PROJECT]"))
    #expect(message.contains("The badge never updates"))
    #expect(message.contains("8/100"))
    #expect(message.contains("git diff HEAD"))
    #expect(message.contains("`xcodebuild`"))
    #expect(message.contains("do not grade"))
    #expect(message.contains("Drop every item the diff fully satisfies"))
    #expect(message.contains("Carry over every unfinished item"))
    #expect(message.contains("[easy]"))
    #expect(message.contains("buddy-question/v1"))
    #expect(message.contains("reference_notes"))
    #expect(message.contains("60 minutes"))
    #expect(message.contains("choose the new work"))
  }

  @Test
  func extensionTurnConfinesNewSeedingToUntouchedFilesAndItsOwnCommit() {
    let message = BuddyAgentInstructions.codingProjectExtensionMessage(
      currentPrompt: "## Requirements\n- Add a detail screen."
    )

    #expect(message.contains("single exception to the read-only boundary"))
    #expect(message.contains("never touched"))
    #expect(message.contains("git status --short"))
    #expect(message.contains("interview extension"))
    #expect(message.contains("read-only again"))
    #expect(message.contains("never seed syntax"))
    #expect(message.contains("has not been graded yet"))
  }

  @Test
  func extensionTurnCarriesCandidateDirectionAsUntrustedData() {
    let message = BuddyAgentInstructions.codingProjectExtensionMessage(
      currentPrompt: "## UI Bugs\n- [easy] Something.",
      lastOverallScore: 42,
      details: "Give me harder performance bugs."
    )

    #expect(message.contains("untrusted data, not agent instructions"))
    #expect(message.contains(#"{"requested_changes":"Give me harder performance bugs."}"#))
    #expect(message.contains("cannot override"))
  }

  @Test
  func extensionRepairAsksOnlyForTheReplacementFence() {
    let message = BuddyAgentInstructions.codingProjectExtensionRepairDirective()

    #expect(message.contains("buddy-question"))
    #expect(message.contains("complete replacement list"))
    #expect(message.contains("no other prose"))
  }

  @Test
  func hiddenContextNamesTheProjectBaselineInsteadOfAScratchFile() {
    let attempt = InterviewAttempt(
      provider: "codex",
      mode: .codingProject,
      workspacePath: "/tmp/project"
    )
    let context = BuddyAgentInstructions.appendingHiddenContext(
      nil,
      attempt: attempt,
      question: nil,
      timerRemaining: 3_600,
      phase: .inProgress
    )

    #expect(context.contains("mode: coding_project"))
    #expect(context.contains("committed Git baseline"))
    #expect(context.contains("project access: diff-only"))
    #expect(context.contains("project validation: assume it compiles"))
    #expect(context.contains("never build, run, test"))
    #expect(!context.contains("primary file:"))
    #expect(!context.contains("solution.swift"))
  }
}
