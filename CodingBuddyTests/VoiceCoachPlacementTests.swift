import Foundation
import Testing

struct VoiceCoachPlacementTests {
  @Test
  func voiceCoachLivesInTheComposerInsteadOfTheSurfaceToolbar() throws {
    let mainContentSource = try sourceContents("CodingBuddy/MainContentView.swift")
    let chatPanelSource = try sourceContents(
      "Packages/CodingBuddyChat/Sources/CodingBuddyChat/ChatPanelView.swift"
    )

    #expect(!mainContentSource.contains("CodingBuddyVoiceSessionControl("))
    #expect(chatPanelSource.contains("voiceCoachAction:"))
    #expect(chatPanelSource.contains("chatComposerVoiceCoachAction("))
  }

  private func sourceContents(_ relativePath: String) throws -> String {
    try String(
      contentsOf: repositoryRoot.appendingPathComponent(relativePath),
      encoding: .utf8
    )
  }

  private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
