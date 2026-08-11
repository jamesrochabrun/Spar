import Foundation
import Testing

struct SystemDesignOnboardingSourceTests {
  @Test
  func onboardingShowsSetupProgressWithAManualFallbackOnly() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/SystemDesignWhiteboardEmptyView.swift"
    )

    // The kickoff creates the canvas, so the placeholder is progress + a
    // manual fallback — no chat-focus detour.
    #expect(!source.contains("\"Focus Chat\""))
    #expect(source.contains("\"Create Whiteboard\""))
    #expect(source.contains("ProgressView"))
    #expect(source.contains("AppBrand.name) is setting up the whiteboard"))
    #expect(source.contains("Wait for \\(AppBrand.name) to finish responding"))
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
