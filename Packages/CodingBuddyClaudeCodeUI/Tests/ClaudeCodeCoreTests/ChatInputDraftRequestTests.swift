import Testing
@testable import ClaudeCodeCore

struct ChatInputDraftRequestTests {
  @Test
  func mergesDictationIntoAnExistingComposerDraft() {
    let request = ChatInputDraftRequest(text: "  explain the edge case  ")

    #expect(
      request.merging(into: "I think this is O(n).")
        == "I think this is O(n). explain the edge case"
    )
  }

  @Test
  func trimsAnEmptyComposerAndTranscript() {
    #expect(ChatInputDraftRequest(text: "  hello  ").merging(into: "  ") == "hello")
    #expect(ChatInputDraftRequest(text: "  ").merging(into: "draft") == "draft")
  }
}
