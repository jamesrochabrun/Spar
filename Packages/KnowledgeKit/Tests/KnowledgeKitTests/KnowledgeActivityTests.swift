import Testing
@testable import KnowledgeKit

struct KnowledgeActivityTests {
  @Test
  func interviewSummaryUsesSparBranding() {
    #expect(KnowledgeActivity.interview.summary.contains("Spar"))
    #expect(!KnowledgeActivity.interview.summary.contains("Buddy"))
  }
}
