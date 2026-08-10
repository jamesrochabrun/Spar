import Testing

@testable import CodingBuddyChat

@Suite("Workspace file content synchronization")
struct WorkspaceFileContentSyncTests {
  @Test
  func reloadsAgentWrittenContentOverACleanStaleBuffer() {
    #expect(WorkspaceFileContentSync.resolution(
      diskContent: "struct Loaded {}\n",
      baselineContent: "candidate draft\n",
      editorContent: "candidate draft\n"
    ) == .reloadFromDisk)
  }

  @Test
  func detectsConcurrentAgentAndCandidateEdits() {
    #expect(WorkspaceFileContentSync.resolution(
      diskContent: "agent solution\n",
      baselineContent: "starter\n",
      editorContent: "candidate solution\n"
    ) == .conflict)
  }

  @Test
  func acknowledgesWhenDiskMatchesTheEditor() {
    #expect(WorkspaceFileContentSync.resolution(
      diskContent: "candidate solution\n",
      baselineContent: "starter\n",
      editorContent: "candidate solution\n"
    ) == .acknowledgeEditor)
  }

  @Test
  func leavesEditorAloneWhenDiskStillMatchesItsBaseline() {
    #expect(WorkspaceFileContentSync.resolution(
      diskContent: "let value = 1\n",
      baselineContent: "let value = 1\n",
      editorContent: "let value = 2\n"
    ) == .unchanged)
  }
}
