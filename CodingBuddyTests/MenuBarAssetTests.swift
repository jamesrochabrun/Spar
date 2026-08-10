//
//  MenuBarAssetTests.swift
//  CodingBuddyTests
//

import AppKit
import Testing
@testable import CodingBuddy

struct MenuBarAssetTests {

  @Test @MainActor
  func preparationSymbolIsAvailableForMenuBarUse() throws {
    let image = try #require(AppDelegate.makeStatusItemImage())

    #expect(image.isTemplate)
    #expect(image.accessibilityDescription == "Spar")
  }
}
