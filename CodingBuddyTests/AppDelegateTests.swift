//
//  AppDelegateTests.swift
//  CodingBuddyTests
//

import AppKit
import Testing
@testable import CodingBuddy

@MainActor
struct AppDelegateTests {

  @Test
  func statusMenuOmitsOpenChatBarWhenFloatingChatBarIsDisabled() {
    let delegate = AppDelegate(
      isFloatingChatBarEnabled: false,
      softwareUpdater: MockSoftwareUpdater()
    )

    let titles = delegate.buildStatusMenu().items.map(\.title)

    #expect(titles.contains("Open App Window"))
    #expect(!titles.contains("Open Chat Bar"))
    #expect(titles.contains("Check for Updates..."))
    #expect(titles.contains("Quit CodingBuddy"))
  }

  @Test
  func statusMenuIncludesOpenChatBarWhenFloatingChatBarIsEnabled() {
    let delegate = AppDelegate(
      isFloatingChatBarEnabled: true,
      softwareUpdater: MockSoftwareUpdater()
    )

    let titles = delegate.buildStatusMenu().items.map(\.title)

    #expect(titles.contains("Open App Window"))
    #expect(titles.contains("Open Chat Bar"))
    #expect(titles.contains("Check for Updates..."))
    #expect(titles.contains("Quit CodingBuddy"))
  }

  @Test
  func checkForUpdatesActionInvokesSoftwareUpdater() {
    let softwareUpdater = MockSoftwareUpdater()
    let delegate = AppDelegate(
      isFloatingChatBarEnabled: false,
      softwareUpdater: softwareUpdater
    )

    delegate.checkForUpdatesFromMenu(nil)

    #expect(softwareUpdater.checkForUpdatesCallCount == 1)
  }
}

@MainActor
private final class MockSoftwareUpdater: SoftwareUpdating {
  private(set) var checkForUpdatesCallCount = 0

  func checkForUpdates() {
    checkForUpdatesCallCount += 1
  }
}
