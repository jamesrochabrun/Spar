//
//  BuddyInterviewSettingsTests.swift
//  CodingBuddyChatTests
//

import Foundation
import InterviewKit
import Testing
@testable import CodingBuddyChat

@MainActor
struct BuddyInterviewSettingsTests {

  private func makeSuite() -> (UserDefaults, String) {
    let name = "BuddyInterviewSettingsTests-\(UUID().uuidString)"
    return (UserDefaults(suiteName: name)!, name)
  }

  @Test
  func defaultsToiOSWhenNothingStored() {
    let (suite, name) = makeSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let settings = BuddyInterviewSettings(defaults: suite)
    #expect(settings.specialization == .iOS)
  }

  @Test
  func persistsSelectionAcrossInstances() {
    let (suite, name) = makeSuite()
    defer { suite.removePersistentDomain(forName: name) }

    let settings = BuddyInterviewSettings(defaults: suite)
    settings.specialization = .general

    let reloaded = BuddyInterviewSettings(defaults: suite)
    #expect(reloaded.specialization == .general)
  }

  @Test
  func fallsBackToDefaultOnUnknownStoredValue() {
    let (suite, name) = makeSuite()
    defer { suite.removePersistentDomain(forName: name) }
    suite.set("android", forKey: BuddyInterviewSettings.specializationKey)

    let settings = BuddyInterviewSettings(defaults: suite)
    #expect(settings.specialization == .default)
  }
}
