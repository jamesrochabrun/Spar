import Foundation

public enum CodingProjectPreparationError: LocalizedError, Equatable {
  case sourceIsNotDirectory
  case xcodeProjectNotFound
  case workspaceIsNotEmpty
  case gitFailed(String)

  public var errorDescription: String? {
    switch self {
    case .sourceIsNotDirectory:
      return "Choose a folder containing an Xcode project or workspace."
    case .xcodeProjectNotFound:
      return "No .xcodeproj or .xcworkspace was found in the selected folder."
    case .workspaceIsNotEmpty:
      return "The managed Xcode project folder is not empty."
    case .gitFailed(let details):
      return "Could not create the interview Git baseline: \(details)"
    }
  }
}
