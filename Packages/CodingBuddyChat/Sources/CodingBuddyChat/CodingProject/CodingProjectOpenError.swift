import Foundation

public enum CodingProjectOpenError: LocalizedError, Equatable {
  case projectNotFound
  case xcodeNotFound
  case launchFailed(String)

  public var errorDescription: String? {
    switch self {
    case .projectNotFound:
      return "The Xcode project could not be found."
    case .xcodeNotFound:
      return "Xcode is not installed or could not be located."
    case .launchFailed(let details):
      return "Could not open the project in Xcode: \(details)"
    }
  }
}
