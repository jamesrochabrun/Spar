import Testing
@testable import CodingBuddyChat

struct CodingProjectRequirementsParserTests {
  @Test
  func turnsMarkdownSectionsIntoRequirementLists() throws {
    let sections = CodingProjectRequirementsParser.parse(
      """
      ## Requirements
      - Show saved articles offline.
      - [ ] Add loading and empty states.

      ## Acceptance Criteria
      1. The project builds.
      2) The focused tests pass.

      ## Starting Points
      - `ArticleStore.swift`

      ## Bugs to Diagnose
      - Refreshing twice duplicates the visible rows.
      """
    )

    #expect(sections.map(\.title) == [
      "Requirements",
      "Acceptance Criteria",
      "Starting Points",
      "Bugs to Diagnose",
    ])
    #expect(sections[0].items == ["Show saved articles offline.", "Add loading and empty states."])
    #expect(sections[1].items == ["The project builds.", "The focused tests pass."])
    #expect(sections[2].items == ["`ArticleStore.swift`"])
    #expect(sections[3].items == ["Refreshing twice duplicates the visible rows."])
  }

  @Test
  func preservesPlainPromptLinesAsRequirements() {
    let sections = CodingProjectRequirementsParser.parse(
      "Add search to the existing list.\nKeep the UI responsive."
    )

    #expect(sections == [CodingProjectRequirementSection(
      title: "Requirements",
      items: ["Add search to the existing list.", "Keep the UI responsive."]
    )])
  }
}
