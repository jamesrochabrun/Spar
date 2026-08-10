enum WorkspaceFileContentSync {
  static func shouldReload(
    diskContent: String,
    displayedContent: String,
    hasUnsavedChanges: Bool
  ) -> Bool {
    !hasUnsavedChanges && diskContent != displayedContent
  }
}
