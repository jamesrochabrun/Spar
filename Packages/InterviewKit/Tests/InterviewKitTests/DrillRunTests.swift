//
//  DrillRunTests.swift
//  InterviewKitTests
//

import Foundation
import Testing
@testable import InterviewKit

struct DrillRepParserTests {

  @Test
  func parsesVerdictWithTopicsAndDifficulty() {
    let block = """
      {"schema":"buddy-rep/v1","verdict":"partial","question_title":"Two Sum",
       "topics":["hash-maps"],"difficulty":"easy","note":"Missed the duplicate case."}
      """
    let rep = DrillRepParser.parse(block, index: 3)
    #expect(rep?.index == 3)
    #expect(rep?.verdict == .partial)
    #expect(rep?.questionTitle == "Two Sum")
    #expect(rep?.topicIds == ["hash-maps"])
    #expect(rep?.difficulty == .easy)
    #expect(rep?.note == "Missed the duplicate case.")
  }

  @Test
  func defaultsDifficultyAndToleratesMissingOptionals() {
    let rep = DrillRepParser.parse(#"{"schema":"buddy-rep/v1","verdict":"CORRECT",}"#, index: 1)
    #expect(rep?.verdict == .correct)
    #expect(rep?.difficulty == .medium)
    #expect(rep?.questionTitle == nil)
    #expect(rep?.note == nil)
    #expect(rep?.topicIds.isEmpty == true)
  }

  @Test
  func rejectsUnknownVerdictsAndForeignSchemas() {
    #expect(DrillRepParser.parse(#"{"schema":"buddy-rep/v1","verdict":"great"}"#, index: 1) == nil)
    #expect(DrillRepParser.parse(#"{"schema":"buddy-eval/v1","verdict":"correct"}"#, index: 1) == nil)
    #expect(DrillRepParser.parse("not json", index: 1) == nil)
  }
}

struct DrillRunTests {

  private func run(_ verdicts: [(DrillVerdict, Difficulty)]) -> DrillRun {
    var run = DrillRun()
    for (offset, entry) in verdicts.enumerated() {
      run.append(DrillRep(index: offset + 1, difficulty: entry.1, verdict: entry.0))
    }
    return run
  }

  @Test
  func tracksTallyAndStreaks() {
    let drill = run([(.correct, .medium), (.incorrect, .medium), (.correct, .easy), (.correct, .easy)])
    #expect(drill.repCount == 4)
    #expect(drill.cleanCount == 3)
    #expect(drill.currentStreak == 2)
    #expect(drill.currentStruggleStreak == 0)
    #expect(drill.nextIndex == 5)
  }

  @Test
  func partialBreaksTheStreakWithoutCountingAsClean() {
    let drill = run([(.correct, .medium), (.partial, .medium)])
    #expect(drill.cleanCount == 1)
    #expect(drill.currentStreak == 0)
    #expect(drill.currentStruggleStreak == 1)
  }

  @Test
  func difficultyLadderStepsUpAfterTwoCleanAndDownAfterTwoStruggles() {
    #expect(run([]).suggestedNextDifficulty(startingFrom: .easy) == .easy)

    let hot = run([(.correct, .easy), (.correct, .easy)])
    #expect(hot.suggestedNextDifficulty(startingFrom: .easy) == .medium)

    let cold = run([(.incorrect, .hard), (.partial, .hard)])
    #expect(cold.suggestedNextDifficulty(startingFrom: .medium) == .medium)

    // A single clean solve holds the line rather than jumping the candidate.
    let mixed = run([(.incorrect, .medium), (.correct, .medium)])
    #expect(mixed.suggestedNextDifficulty(startingFrom: .medium) == .medium)
  }

  @Test
  func ladderClampsAtBothEnds() {
    let topped = run([(.correct, .hard), (.correct, .hard)])
    #expect(topped.suggestedNextDifficulty(startingFrom: .hard) == .hard)

    let bottomed = run([(.incorrect, .easy), (.incorrect, .easy)])
    #expect(bottomed.suggestedNextDifficulty(startingFrom: .easy) == .easy)
  }

  @Test
  func shakyTopicsListMissesMostRecentFirstWithoutDuplicates() {
    var drill = DrillRun()
    drill.append(DrillRep(index: 1, topicIds: ["hash-maps"], verdict: .incorrect))
    drill.append(DrillRep(index: 2, topicIds: ["two-pointers"], verdict: .correct))
    drill.append(DrillRep(index: 3, topicIds: ["hash-maps", "sorting"], verdict: .partial))

    #expect(drill.shakyTopicIds == ["hash-maps", "sorting"])
  }
}

struct DrillRepCaptureTests {

  @Test
  func captureNumbersRepsFromTheRunsOwnCounter() {
    let message = """
      ```buddy-rep
      {"schema":"buddy-rep/v1","verdict":"correct","topics":["arrays"]}
      ```
      Nice — next one.
      ```buddy-question
      {"schema":"buddy-question/v1","title":"Merge Intervals","difficulty":"medium","prompt_markdown":"…"}
      ```
      """

    let results = StructuredBlockCapture.capture(
      messageText: message,
      mode: .drill,
      attemptId: "attempt-1",
      nextRepIndex: 4
    )

    // The verdict for the finished rep must land before the next question.
    guard case .drillRep(let captured) = results.first else {
      Issue.record("expected the rep to be captured first")
      return
    }
    #expect(captured.rep.index == 4)
    #expect(captured.rep.verdict == .correct)
    #expect(results.count == 2)
  }

  @Test
  func repFencesAreIgnoredOutsideDrills() {
    let message = """
      ```buddy-rep
      {"schema":"buddy-rep/v1","verdict":"correct"}
      ```
      """
    let results = StructuredBlockCapture.capture(
      messageText: message,
      mode: .mockInterview,
      attemptId: "attempt-1"
    )
    #expect(results.isEmpty)
    #expect(BuddyFence.containsBuddyFence(message))
  }
}
