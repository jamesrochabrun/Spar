import Foundation
import Testing

struct SystemDesignOnboardingSourceTests {
  @Test
  func onboardingOffersRealActionsWithoutFakeProgress() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/SystemDesignWhiteboardEmptyView.swift"
    )

    #expect(source.contains("\"Focus Chat\""))
    #expect(source.contains("\"Create Whiteboard\""))
    #expect(source.contains("ProgressView"))
    #expect(source.contains("Wait for Buddy to finish responding"))
    #expect(!source.contains("static let phases"))
    #expect(!source.contains("users, scale, consistency"))
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
