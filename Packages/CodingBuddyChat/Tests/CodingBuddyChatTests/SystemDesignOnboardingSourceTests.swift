import Foundation
import Testing

struct SystemDesignOnboardingSourceTests {
  @Test
  func onboardingOffersChatAndWhiteboardActions() throws {
    let source = try sourceContents(
      "Sources/CodingBuddyChat/Surfaces/SystemDesignWhiteboardEmptyView.swift"
    )

    #expect(source.contains("\"Continue in Chat\""))
    #expect(source.contains("\"Create Whiteboard\""))
    #expect(source.contains("\"Requirements\""))
    #expect(source.contains("\"Architecture\""))
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
