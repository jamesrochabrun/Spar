import HighlightSwift
import XCTest
@testable import ClaudeCodeCore

final class ChatMarkdownRenderingTests: XCTestCase {
  func testCompletedMarkdownIsNotChanged() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    # Heading

    - Item
    - [Link](https://example.com)

    ```swift
    let value = 1
    ```
    """

    XCTAssertEqual(renderer.displayMarkdown(for: markdown, isComplete: true), markdown)
  }

  func testStreamingMarkdownClosesUnfinishedBacktickFenceForDisplay() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    Before

    ```swift
    let value = 1
    """

    XCTAssertEqual(
      renderer.displayMarkdown(for: markdown, isComplete: false),
      """
      Before

      ```swift
      let value = 1
      ```
      """
    )
  }

  func testStreamingMarkdownClosesUnfinishedTildeFenceWithMatchingLength() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    ~~~~json
    {"name":"Easel"}
    """

    XCTAssertEqual(
      renderer.displayMarkdown(for: markdown, isComplete: false),
      """
      ~~~~json
      {"name":"Easel"}
      ~~~~
      """
    )
  }

  func testClosedStreamingFenceIsNotChanged() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
    ```swift
    let value = 1
    ```

    Done
    """

    XCTAssertEqual(renderer.displayMarkdown(for: markdown, isComplete: false), markdown)
  }

  func testLanguageMapperUsesKnownHighlightLanguages() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    XCTAssertEqual(mapper.highlightMode(for: "swift"), .languageIgnoreIllegal(.swift))
    XCTAssertEqual(mapper.highlightMode(for: "ts"), .languageIgnoreIllegal(.typeScript))
    XCTAssertEqual(mapper.highlightMode(for: "bash"), .languageIgnoreIllegal(.bash))
  }

  func testLanguageMapperNormalizesFenceInfoAndUnknownAliases() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    XCTAssertEqual(mapper.highlightMode(for: "swift:Sources/App.swift"), .languageIgnoreIllegal(.swift))
    XCTAssertEqual(mapper.highlightMode(for: "customlang title"), .languageAliasIgnoreIllegal("customlang"))
    XCTAssertEqual(mapper.highlightMode(for: nil), .automatic)
  }

  func testLanguageMapperProvidesDisplayNamesForAliases() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    XCTAssertEqual(mapper.displayName(for: "ts"), "typescript")
    XCTAssertEqual(mapper.displayName(for: "py"), "python")
    XCTAssertEqual(mapper.displayName(for: "swift:Sources/App.swift"), "swift")
  }

  func testLanguageMapperIdentifiesMermaidFenceInfo() {
    let mapper = ChatMarkdownCodeLanguageMapper()

    XCTAssertTrue(mapper.isMermaid("mermaid"))
    XCTAssertTrue(mapper.isMermaid("mermaid diagram"))
    XCTAssertFalse(mapper.isMermaid("markdown"))
  }

  func testStudyPlanFenceCollapsesToSavedChip() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
      ```buddy-study-plan
      {"schema":"buddy-study-plan/v1","title":"Plan","items":[]}
      ```
      """

    XCTAssertEqual(
      renderer.displayMarkdown(for: markdown, isComplete: true),
      "`📚 Study plan saved`"
    )
  }

  func testLessonFenceCollapsesAndKeepsSurroundingProse() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
      Here's your next task.

      ```buddy-lesson
      {"schema":"buddy-lesson/v1","item_id":"storage","step":1,"total_steps":3,
       "outcome":"Explain the migration order.","scenario_markdown":"A migration fails.",
       "inspect_steps":["Find the rollback path"]}
      ```
      """

    // The contract JSON never reaches the transcript — the Lesson tab renders
    // it — but the agent's short intro line still does.
    XCTAssertEqual(
      renderer.displayMarkdown(for: markdown, isComplete: true),
      """
      Here's your next task.

      `🎓 Lesson shown in the Lesson tab`
      """
    )
  }

  func testUnterminatedLessonFenceCollapsesToStreamingChip() {
    let renderer = DefaultChatMarkdownRenderer()
    let markdown = """
      ```buddy-lesson
      {"schema":"buddy-lesson/v1","item_id":"storage",
      """

    // Mid-stream the JSON must stay hidden too, or the learner watches a raw
    // object type itself out.
    XCTAssertEqual(
      renderer.displayMarkdown(for: markdown, isComplete: true),
      "`🎓 Preparing lesson…`"
    )
  }
}
