import Testing
@testable import KnowledgeKit

struct StudyPlanContextBuilderTests {
  @Test
  func contextCarriesLiveCompletionAndNextItem() {
    let plan = StudyPlan(
      id: "plan",
      studySpaceID: "space",
      title: "Repository Plan",
      summary: "Understand the app.",
      items: [
        StudyPlanItem(
          id: "orientation",
          section: "Foundations",
          title: "Orientation",
          objective: "Map the packages.",
          isCompleted: true,
          completedAt: .now
        ),
        StudyPlanItem(
          id: "data-flow",
          section: "Foundations",
          title: "Data Flow",
          objective: "Trace a request."
        ),
      ]
    )

    let context = StudyPlanContextBuilder.makeContext(plan: plan)

    #expect(context.contains("<buddy-study-plan-state>"))
    #expect(context.contains("\"completedCount\":1"))
    #expect(context.contains("\"nextItemID\":\"data-flow\""))
    #expect(context.contains("\"isCompleted\":true"))
  }
}
