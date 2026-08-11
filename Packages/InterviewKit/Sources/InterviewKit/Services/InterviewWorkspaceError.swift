import Foundation

public enum InterviewWorkspaceError: LocalizedError, Sendable {
  case unmanagedPath(String)

  public var errorDescription: String? {
    switch self {
    case .unmanagedPath:
      return "The project is outside Spar's managed Workspaces folder."
    }
  }
}
