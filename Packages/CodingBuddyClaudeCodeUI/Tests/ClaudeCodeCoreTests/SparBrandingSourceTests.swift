import Foundation
import XCTest

final class SparBrandingSourceTests: XCTestCase {
  func testVisibleRuntimeBrandingUsesSpar() throws {
    let relativePaths = [
      "Sources/ClaudeCodeCore/UI/LoadingIndicator.swift",
      "Sources/ClaudeCodeCore/UI/ChatScreen.swift",
      "Sources/ClaudeCodeCore/UI/ChatMessageView/ChatMessageView.swift",
      "Sources/ClaudeCodeCore/Models/LocalAgentLaunchError.swift",
      "Sources/ClaudeCodeCore/Models/ErrorInfo.swift",
    ]

    for relativePath in relativePaths {
      let source = try sourceContents(relativePath)
      XCTAssertNil(
        source.range(
          of: #"\b(Buddy|Easel|CodingBuddy)\b"#,
          options: .regularExpression
        ),
        "Legacy branding remains in \(relativePath)"
      )
    }
  }

  func testLoadingFallbackUsesConfiguredAppName() throws {
    let loadingSource = try sourceContents(
      "Sources/ClaudeCodeCore/UI/LoadingIndicator.swift"
    )
    let chatSource = try sourceContents(
      "Sources/ClaudeCodeCore/UI/ChatScreen.swift"
    )

    XCTAssertTrue(loadingSource.contains("AppBrand.name) is working"))
    XCTAssertTrue(chatSource.contains("uiConfiguration.appName) is working"))
  }

  private func sourceContents(_ relativePath: String) throws -> String {
    let testsDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let packageDirectory = testsDirectory.deletingLastPathComponent()
    return try String(
      contentsOf: packageDirectory.appendingPathComponent(relativePath),
      encoding: .utf8
    )
  }
}
