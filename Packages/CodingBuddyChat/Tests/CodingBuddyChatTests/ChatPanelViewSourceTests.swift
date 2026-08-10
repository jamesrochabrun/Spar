import Foundation
import Testing

struct ChatPanelViewSourceTests {
  @Test
  func chatScreenIdentityTracksCurrentViewModel() throws {
    let source = try sourceContents("Sources/CodingBuddyChat/ChatPanelView.swift")

    #expect(source.contains(".id(ObjectIdentifier(vm))"))
  }

  @Test
  func homeAndSettingsUseTheSharedSparBrand() throws {
    let sidebar = try sourceContents("Sources/CodingBuddyChat/Sidebar/SidebarView.swift")
    let chatPanel = try sourceContents("Sources/CodingBuddyChat/ChatPanelView.swift")
    let settings = try sourceContents("Sources/CodingBuddyChat/CodingBuddyChatSettingsView.swift")

    #expect(sidebar.contains("Text(AppBrand.name)"))
    #expect(sidebar.contains("Image(systemName: AppBrand.symbolName)"))
    #expect(chatPanel.contains("appName: AppBrand.name"))
    #expect(settings.contains("appName: AppBrand.name"))
    #expect(!sidebar.contains("Text(\"CodingBuddy\")"))
    #expect(!sidebar.contains("Image(\"easelmenubar\")"))
    #expect(!settings.contains("appName: \"CodingBuddy\""))
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
