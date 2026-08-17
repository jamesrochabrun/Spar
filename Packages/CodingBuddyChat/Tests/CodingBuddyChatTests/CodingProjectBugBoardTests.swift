import InterviewKit
import Testing
@testable import CodingBuddyChat

struct CodingProjectBugBoardTests {

  private func board(_ markdown: String) -> (
    board: [CodingProjectBugSection],
    remainder: [CodingProjectRequirementSection]
  ) {
    CodingProjectBugBoard.split(CodingProjectRequirementsParser.parse(markdown))
  }

  @Test
  func splitsCategorySectionsIntoIndependentDifficultyLadders() {
    let result = board(
      """
      ## UI Bugs
      - [hard] The detail sheet keeps a stale title after a swipe back.
      - [easy] The cart badge does not update after adding an item.

      ## Data & State Bugs
      - [medium] Editing a quantity updates the row but not the store.

      ## Constraints
      - Swift + SwiftUI only.
      """
    )

    #expect(result.board.map(\.title) == ["UI Bugs", "Data & State Bugs"])
    #expect(result.remainder.map(\.title) == ["Constraints"])

    // Each category sorts its own ladder easy first, independent of the others.
    #expect(result.board[0].bugs.map(\.difficulty) == [.easy, .hard])
    #expect(result.board[0].bugs[0].text == "The cart badge does not update after adding an item.")
    #expect(result.board[0].difficultyRange == "Easy–Hard")
    #expect(result.board[1].bugs.map(\.difficulty) == [.medium])
    #expect(result.board[1].difficultyRange == "Medium")
  }

  @Test
  func acceptsTheTagFormsAnAgentActuallyWrites() {
    let result = board(
      """
      ## Performance Bugs
      - (Easy) Scrolling stutters after ten inserts.
      - **hard**: The list rebuilds every row on each keystroke.
      - [medium] — Filtering recomputes the whole store.
      - No tag here, so it lands in the middle.
      """
    )

    let bugs = result.board[0].bugs
    #expect(bugs.map(\.difficulty) == [.easy, .medium, .medium, .hard])
    #expect(bugs[0].text == "Scrolling stutters after ten inserts.")
    #expect(bugs[1].text == "Filtering recomputes the whole store.")
    #expect(bugs[2].text == "No tag here, so it lands in the middle.")
    #expect(bugs[3].text == "The list rebuilds every row on each keystroke.")
  }

  @Test
  func featureExerciseKeepsItsRequirementsAndHasNoBoard() {
    let result = board(
      """
      ## Requirements
      - Add offline caching.

      ## Acceptance Criteria
      - Saved articles open with no network.

      ## Starting Points
      - `ArticleStore.swift`
      """
    )

    #expect(result.board.isEmpty)
    #expect(result.remainder.map(\.title) == ["Requirements", "Acceptance Criteria", "Starting Points"])
  }

  @Test
  func recognizesTheOlderSingleBugSectionAsACategory() {
    let result = board(
      """
      ## Bugs to Diagnose
      - Refreshing twice duplicates the visible rows.
      """
    )

    #expect(result.board.map(\.title) == ["Bugs to Diagnose"])
    #expect(result.board[0].bugs.count == 1)
    #expect(result.remainder.isEmpty)
  }

  @Test
  func chipDropsTheRedundantBugsSuffix() {
    #expect(CodingProjectBugBoard.categoryName("UI Bugs") == "UI")
    #expect(CodingProjectBugBoard.categoryName("Data & State Bugs") == "Data & State")
    #expect(CodingProjectBugBoard.categoryName("Bugs to Diagnose") == "Bugs to Diagnose")
  }
}
