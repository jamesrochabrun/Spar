enum WorkspaceFileContentSync {
  enum Resolution: Equatable {
    /// The file on disk still matches the content the editor originally loaded.
    case unchanged
    /// Disk changed while the editor stayed clean, so the disk version wins.
    case reloadFromDisk
    /// Disk now matches the editor buffer, so the external write acknowledges it.
    case acknowledgeEditor
    /// Both disk and the editor changed from their common baseline.
    case conflict
  }

  /// Reconciles the three versions involved when provider tools and the editor
  /// can both write the selected file. Comparing only a boolean "dirty" flag
  /// is not enough: delayed editor callbacks can otherwise make a clean buffer
  /// look dirty and leave it stale.
  static func resolution(
    diskContent: String,
    baselineContent: String,
    editorContent: String
  ) -> Resolution {
    if diskContent == baselineContent {
      return .unchanged
    }
    if diskContent == editorContent {
      return .acknowledgeEditor
    }
    if editorContent == baselineContent {
      return .reloadFromDisk
    }
    return .conflict
  }
}
