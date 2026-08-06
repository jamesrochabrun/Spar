import Testing
@testable import KnowledgeKit

struct StudyPlanBlockParserTests {
  @Test
  func parsesPlanFenceAndNormalizesStableUniqueIDs() throws {
    let message = """
      I analyzed the repository.

      ```buddy-study-plan
      {"schema":"buddy-study-plan/v1","title":"Learn CodingBuddy","summary":"Follow the session flow.",
       "items":[
         {"id":"Session Flow","section":"Foundations","title":"Trace a session","objective":"Explain session creation.","topics":["architecture"],"source_paths":["Sources/ChatService.swift"],"prerequisite_ids":[]},
         {"id":"Session Flow","section":"Testing","title":"Test a session","objective":"Find the integration tests.","source_paths":["Tests/ChatServiceTests.swift"],},
       ],}
      ```
      """

    let plan = try #require(
      StudyPlanBlockParser.parseBlocks(in: message, studySpaceID: "space-1").first
    )

    #expect(plan.id == "study-plan-space-1")
    #expect(plan.title == "Learn CodingBuddy")
    #expect(plan.items.map(\.id) == ["session-flow", "session-flow-2"])
    #expect(plan.items[0].topics == ["architecture"])
    #expect(plan.items[1].section == "Testing")
  }

  @Test
  func rejectsWrongSchemaAndEmptyItems() {
    let wrongSchema = """
      {"schema":"buddy-question/v1","title":"Nope","items":[{"title":"Item"}]}
      """
    let empty = """
      {"schema":"buddy-study-plan/v1","title":"Empty","items":[]}
      """

    #expect(StudyPlanBlockParser.parse(wrongSchema, studySpaceID: "space") == nil)
    #expect(StudyPlanBlockParser.parse(empty, studySpaceID: "space") == nil)
  }
}
