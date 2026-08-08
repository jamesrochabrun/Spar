import Testing
@testable import KnowledgeKit

struct LessonBlockParserTests {

  @Test
  func parsesAnOpeningLessonTurn() throws {
    let message = """
      Here's your first task.

      ```buddy-lesson
      {"schema":"buddy-lesson/v1","item_id":"Stream Routing","item_title":"Routing the stream",
       "step":1,"total_steps":3,
       "outcome":"Explain how tokens reach the view.",
       "why_markdown":"Every visible message flows through one processor.",
       "source":{"path":"Sources/App/StreamProcessor.swift","locator":"lines 112-160","chunk_id":"chunk-9"},
       "scenario_markdown":"A tool_use arrives mid-sentence.",
       "inspect_steps":["Find where the delta is appended","Note what happens to partial text"],
       "reply_scaffold":"Note: ___\\nPrediction: ___ because ___",
       "feedback_markdown":null,"teaches_markdown":null,"item_complete":false}
      ```
      """

    let lesson = try #require(LessonBlockParser.parseBlocks(in: message).first)

    #expect(lesson.itemID == "stream-routing")
    #expect(lesson.itemTitle == "Routing the stream")
    #expect(lesson.step == 1)
    #expect(lesson.totalSteps == 3)
    #expect(lesson.source?.path == "Sources/App/StreamProcessor.swift")
    #expect(lesson.source?.locator == "lines 112-160")
    #expect(lesson.source?.chunkID == "chunk-9")
    #expect(lesson.source?.displayName == "StreamProcessor.swift · lines 112-160")
    #expect(lesson.inspectSteps.count == 2)
    #expect(lesson.replyScaffold.contains("Prediction:"))
    #expect(lesson.isOpeningTurn)
    #expect(!lesson.isClosingTurn)
    #expect(!lesson.isItemComplete)
    #expect(lesson.id == "stream-routing#1")
  }

  @Test
  func parsesAFeedbackTurnCarryingTheNextTask() throws {
    let message = """
      ```buddy-lesson
      {"schema":"buddy-lesson/v1","item_id":"stream-routing","step":2,"total_steps":3,
       "outcome":"Explain how tokens reach the view.",
       "feedback_markdown":"Right about the buffer, but the flush is not where you guessed.",
       "teaches_markdown":"Partial text is retained until a terminal event arrives.",
       "scenario_markdown":"Now a stream errors halfway.",
       "inspect_steps":["Find the error branch"],
       "reply_scaffold":"Note: ___","item_complete":false}
      ```
      """

    let lesson = try #require(LessonBlockParser.parseBlocks(in: message).first)

    #expect(!lesson.isOpeningTurn)
    #expect(!lesson.isClosingTurn)
    #expect(lesson.feedbackMarkdown?.hasPrefix("Right about the buffer") == true)
    #expect(lesson.teachesMarkdown != nil)
    #expect(lesson.step == 2)
  }

  @Test
  func recognizesTheClosingTurn() throws {
    let block = """
      {"schema":"buddy-lesson/v1","item_id":"stream-routing","step":3,"total_steps":3,
       "feedback_markdown":"That's exactly it.",
       "teaches_markdown":"The processor owns ordering, not the view.",
       "scenario_markdown":"","inspect_steps":[],"item_complete":true}
      """

    let lesson = try #require(LessonBlockParser.parse(block))

    #expect(lesson.isClosingTurn)
    #expect(lesson.isItemComplete)
    #expect(!lesson.isOpeningTurn)
  }

  @Test
  func toleratesTrailingCommasQuotedNumbersAndShorthandSource() throws {
    let block = """
      {"schema":"buddy-lesson/v1","item_id":"storage","step":"2","total_steps":"4",
       "outcome":"Explain the migration order.",
       "source":"Sources/Storage/Migrations.swift:runAll()",
       "scenario_markdown":"A migration fails midway.",
       "inspect_steps":["Find the rollback path",],
       "item_complete":"false",}
      """

    let lesson = try #require(LessonBlockParser.parse(block))

    #expect(lesson.step == 2)
    #expect(lesson.totalSteps == 4)
    #expect(lesson.source?.path == "Sources/Storage/Migrations.swift")
    #expect(lesson.source?.locator == "runAll()")
    #expect(lesson.source?.chunkID == nil)
    #expect(!lesson.isItemComplete)
  }

  @Test
  func keepsAPathWithoutALocatorIntact() throws {
    let block = """
      {"schema":"buddy-lesson/v1","item_id":"x","outcome":"Read the entry point.",
       "source":"Sources/App/main.swift","scenario_markdown":"Trace startup.",
       "inspect_steps":["Find the app entry"]}
      """

    let lesson = try #require(LessonBlockParser.parse(block))

    #expect(lesson.source?.path == "Sources/App/main.swift")
    #expect(lesson.source?.locator.isEmpty == true)
    #expect(lesson.source?.displayName == "main.swift")
  }

  @Test
  func clampsInconsistentStepCounts() throws {
    let block = """
      {"schema":"buddy-lesson/v1","item_id":"x","step":5,"total_steps":2,
       "outcome":"Something","scenario_markdown":"A situation","inspect_steps":["Look"]}
      """

    let lesson = try #require(LessonBlockParser.parse(block))

    // total_steps can never be behind the step it is describing.
    #expect(lesson.step == 5)
    #expect(lesson.totalSteps == 5)
  }

  @Test
  func rejectsWrongSchemaAndEmptyTurns() {
    let wrongSchema = """
      {"schema":"buddy-question/v1","item_id":"x","scenario_markdown":"Nope"}
      """
    let nothingToShow = """
      {"schema":"buddy-lesson/v1","item_id":"x","step":1,"total_steps":2,
       "scenario_markdown":"","inspect_steps":[],"why_markdown":"context only"}
      """

    #expect(LessonBlockParser.parse(wrongSchema) == nil)
    #expect(LessonBlockParser.parse(nothingToShow) == nil)
    #expect(LessonBlockParser.parse("not json at all") == nil)
  }

  @Test
  func takesTheLastFenceWhenATurnEmitsSeveral() throws {
    let message = """
      ```buddy-lesson
      {"schema":"buddy-lesson/v1","item_id":"x","step":1,"total_steps":2,"outcome":"First",
       "scenario_markdown":"A","inspect_steps":["Look"]}
      ```

      Correction — use this one:

      ```buddy-lesson
      {"schema":"buddy-lesson/v1","item_id":"x","step":1,"total_steps":2,"outcome":"Second",
       "scenario_markdown":"B","inspect_steps":["Look again"]}
      ```
      """

    let lessons = LessonBlockParser.parseBlocks(in: message)

    #expect(lessons.count == 2)
    #expect(lessons.last?.outcome == "Second")
  }
}
