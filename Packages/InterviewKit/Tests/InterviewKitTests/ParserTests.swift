//
//  ParserTests.swift
//  InterviewKitTests
//

import Foundation
import Testing
@testable import InterviewKit

struct QuestionBlockParserTests {

  @Test
  func parsesValidQuestionBlock() {
    let block = """
      {"schema":"buddy-question/v1","title":"Longest Substring","difficulty":"medium",
       "topics":["sliding-window"],"prompt_markdown":"Given a string…",
       "reference_notes":"Use a window.","language_hint":"swift"}
      """
    let question = QuestionBlockParser.parse(block, fallbackMode: .mockInterview)
    #expect(question?.title == "Longest Substring")
    #expect(question?.difficulty == .medium)
    #expect(question?.topicIds == ["sliding-window"])
    #expect(question?.languageHint == "swift")
    #expect(question?.referenceNotes == "Use a window.")
    #expect(question?.mode == .mockInterview)
  }

  @Test
  func toleratesTrailingCommasAndMissingOptionals() {
    let block = """
      {"schema":"buddy-question/v1","title":"Two Sum","difficulty":"easy",
       "prompt_markdown":"Find two numbers…",}
      """
    let question = QuestionBlockParser.parse(block, fallbackMode: .drill)
    #expect(question?.title == "Two Sum")
    #expect(question?.topicIds.isEmpty == true)
    #expect(question?.languageHint == nil)
  }

  @Test
  func rejectsMissingRequiredFields() {
    let noTitle = """
      {"schema":"buddy-question/v1","difficulty":"easy","prompt_markdown":"x"}
      """
    #expect(QuestionBlockParser.parse(noTitle, fallbackMode: .drill) == nil)

    let noPrompt = """
      {"schema":"buddy-question/v1","title":"X","difficulty":"easy"}
      """
    #expect(QuestionBlockParser.parse(noPrompt, fallbackMode: .drill) == nil)
  }

  @Test
  func rejectsWrongSchema() {
    let block = """
      {"schema":"buddy-eval/v1","title":"X","prompt_markdown":"y"}
      """
    #expect(QuestionBlockParser.parse(block, fallbackMode: .drill) == nil)
  }

  @Test
  func unknownDifficultyDefaultsToMedium() {
    let block = """
      {"schema":"buddy-question/v1","title":"X","difficulty":"brutal","prompt_markdown":"y"}
      """
    #expect(QuestionBlockParser.parse(block, fallbackMode: .drill)?.difficulty == .medium)
  }
}

struct RubricEvaluationParserTests {

  @Test
  func parsesValidEvalBlock() {
    let block = """
      {"schema":"buddy-eval/v1","overall_score":72,"verdict":"lean_hire",
       "dimensions":[{"id":"correctness","score":7,"max":10,"comment":"ok"}],
       "summary_markdown":"Good effort.",
       "improvement_notes":[{"topic":"dynamic-programming","note":"Practice DP."}]}
      """
    let captured = RubricEvaluationParser.parse(block, attemptId: "attempt-1")
    #expect(captured?.evaluation.overallScore == 72)
    #expect(captured?.evaluation.verdict == "lean_hire")
    #expect(captured?.evaluation.dimensionScores.first?.dimension == "correctness")
    #expect(captured?.evaluation.dimensionScores.first?.score == 7)
    #expect(captured?.notes.count == 1)
    #expect(captured?.notes.first?.topicId == "dynamic-programming")
    #expect(captured?.evaluation.attemptId == "attempt-1")
  }

  @Test
  func clampsOutOfRangeScores() {
    let block = """
      {"schema":"buddy-eval/v1","overall_score":140,"summary_markdown":"x"}
      """
    #expect(RubricEvaluationParser.parse(block, attemptId: "a")?.evaluation.overallScore == 100)
  }

  @Test
  func rejectsMissingScore() {
    let block = """
      {"schema":"buddy-eval/v1","summary_markdown":"no score here"}
      """
    #expect(RubricEvaluationParser.parse(block, attemptId: "a") == nil)
  }

  @Test
  func toleratesMalformedNotesEntries() {
    let block = """
      {"schema":"buddy-eval/v1","overall_score":50,"summary_markdown":"x",
       "improvement_notes":[{"topic":"graphs"},{"note":"Real note"},"garbage"]}
      """
    let captured = RubricEvaluationParser.parse(block, attemptId: "a")
    #expect(captured?.notes.count == 1)
    #expect(captured?.notes.first?.noteMarkdown == "Real note")
  }
}

struct StructuredBlockCaptureTests {

  @Test
  func extractsFencedBlocks() {
    let message = """
      Here's your problem:

      ```buddy-question
      {"schema":"buddy-question/v1","title":"Two Sum","difficulty":"easy","prompt_markdown":"Find…"}
      ```

      Let me restate it conversationally…
      """
    let results = StructuredBlockCapture.capture(messageText: message, mode: .drill, attemptId: nil)
    #expect(results.count == 1)
    if case .question(let captured) = results[0] {
      #expect(captured.question.title == "Two Sum")
    } else {
      Issue.record("Expected question capture")
    }
  }

  @Test
  func lastEvalFenceWins() {
    let message = """
      ```buddy-eval
      {"schema":"buddy-eval/v1","overall_score":10,"summary_markdown":"draft"}
      ```
      Correction:
      ```buddy-eval
      {"schema":"buddy-eval/v1","overall_score":80,"summary_markdown":"final"}
      ```
      """
    let results = StructuredBlockCapture.capture(messageText: message, mode: .drill, attemptId: "a")
    #expect(results.count == 1)
    if case .evaluation(let captured) = results[0] {
      #expect(captured.evaluation.overallScore == 80)
    } else {
      Issue.record("Expected evaluation capture")
    }
  }

  @Test
  func noFencesProducesNoResults() {
    let results = StructuredBlockCapture.capture(
      messageText: "Just a normal chat reply with ```swift\nlet x = 1\n``` code.",
      mode: .practice,
      attemptId: "a"
    )
    #expect(results.isEmpty)
  }

  @Test
  func evalIgnoredWithoutAttempt() {
    let message = """
      ```buddy-eval
      {"schema":"buddy-eval/v1","overall_score":80,"summary_markdown":"x"}
      ```
      """
    let results = StructuredBlockCapture.capture(messageText: message, mode: .drill, attemptId: nil)
    #expect(results.isEmpty)
  }

  @Test
  func unterminatedFenceStillCaptured() {
    let message = """
      ```buddy-eval
      {"schema":"buddy-eval/v1","overall_score":66,"summary_markdown":"cut off"}
      """
    let results = StructuredBlockCapture.capture(messageText: message, mode: .drill, attemptId: "a")
    #expect(results.count == 1)
  }

  @Test
  func malformedJSONIsSkipped() {
    let message = """
      ```buddy-question
      {"schema":"buddy-question/v1","title": broken json here
      ```
      """
    let results = StructuredBlockCapture.capture(messageText: message, mode: .drill, attemptId: nil)
    #expect(results.isEmpty)
  }
}
