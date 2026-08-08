enum StudySpaceLearningSection: String, CaseIterable, Identifiable {
  case plan
  case sources

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .plan: return "Learning Plan"
    case .sources: return "Sources"
    }
  }
}
