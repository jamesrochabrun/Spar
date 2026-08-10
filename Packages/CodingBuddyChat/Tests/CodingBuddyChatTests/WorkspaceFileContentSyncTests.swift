import Testing

@testable import CodingBuddyChat

@Suite("Workspace file content synchronization")
struct WorkspaceFileContentSyncTests {
  @Test
  func reloadsAgentWrittenContentOverACleanStaleBuffer() {
    #expect(WorkspaceFileContentSync.shouldReload(
      diskContent: "struct Loaded {}\n",
      displayedContent: "",
      hasUnsavedChanges: false
    ))
  }

  @Test
  func preservesUnsavedCandidateEdits() {
    #expect(!WorkspaceFileContentSync.shouldReload(
      diskContent: "struct Loaded {}\n",
      displayedContent: "candidate draft\n",
      hasUnsavedChanges: true
    ))
  }

  @Test
  func skipsReloadWhenDiskAndEditorAlreadyMatch() {
    #expect(!WorkspaceFileContentSync.shouldReload(
      diskContent: "let value = 1\n",
      displayedContent: "let value = 1\n",
      hasUnsavedChanges: false
    ))
  }
}
