import AppKit
import Foundation

public struct SystemCodingProjectOpener: CodingProjectOpening {
  public init() {}

  @MainActor
  public func openProject(at projectURL: URL) async throws {
    guard FileManager.default.fileExists(atPath: projectURL.path) else {
      throw CodingProjectOpenError.projectNotFound
    }
    guard let xcodeURL = NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: "com.apple.dt.Xcode"
    ) else {
      throw CodingProjectOpenError.xcodeNotFound
    }

    let configuration = NSWorkspace.OpenConfiguration()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      NSWorkspace.shared.open(
        [projectURL],
        withApplicationAt: xcodeURL,
        configuration: configuration
      ) { _, error in
        if let error {
          continuation.resume(
            throwing: CodingProjectOpenError.launchFailed(error.localizedDescription)
          )
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }
}
