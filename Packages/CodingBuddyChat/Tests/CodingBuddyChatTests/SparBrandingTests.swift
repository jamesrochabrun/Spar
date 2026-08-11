import Foundation
import InterviewKit
import Testing
@testable import CodingBuddyChat

struct SparBrandingTests {
  @Test
  func agentIdentifiesItselfAsSpar() {
    let prompt = BuddyAgentInstructions.prefixes(for: .mockInterview).claude

    #expect(prompt.contains("You are Spar, the AI interviewer and coach"))
    #expect(!prompt.contains("You are Buddy"))
  }

  @Test
  func codingBuddyChatSourceHasNoStandaloneLegacyBrandNames() throws {
    let sourcesDirectory = packageDirectory
      .appendingPathComponent("Sources/CodingBuddyChat", isDirectory: true)
    let enumerator = try #require(
      FileManager.default.enumerator(
        at: sourcesDirectory,
        includingPropertiesForKeys: nil
      )
    )

    for case let sourceURL as URL in enumerator where sourceURL.pathExtension == "swift" {
      let source = try String(contentsOf: sourceURL, encoding: .utf8)
      #expect(source.range(
        of: #"\b(Buddy|Easel|CodingBuddy)\b"#,
        options: .regularExpression
      ) == nil, "Legacy branding remains in \(sourceURL.lastPathComponent)")
    }
  }

  private var packageDirectory: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
