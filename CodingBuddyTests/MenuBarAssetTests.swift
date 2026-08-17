//
//  MenuBarAssetTests.swift
//  CodingBuddyTests
//

import AppKit
import Testing
@testable import CodingBuddy

struct MenuBarAssetTests {

  @Test @MainActor
  func sparAssetIsSizedForMenuBarUse() throws {
    let image = try #require(AppDelegate.makeStatusItemImage())

    #expect(image.size == NSSize(width: 18, height: 18))
    #expect(image.isTemplate)
    #expect(image.accessibilityDescription == "Spar")
  }
}
