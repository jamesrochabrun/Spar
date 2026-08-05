//
//  SpecializationPromptFactoryTests.swift
//  CodingBuddyChatTests
//

import InterviewKit
import Testing
@testable import CodingBuddyChat

struct SpecializationPromptFactoryTests {

  @Test
  func generalTrackIsEmptyEverywhere() {
    for mode in SessionMode.allCases {
      #expect(SpecializationPromptFactory.sessionGuidance(.general, mode: mode).isEmpty)
      #expect(SpecializationPromptFactory.compactGuidance(.general, mode: mode).isEmpty)
      #expect(SpecializationPromptFactory.evaluationGuidance(.general, mode: mode).isEmpty)
    }
  }

  @Test
  func iOSTrackCoversEveryMode() {
    for mode in SessionMode.allCases {
      let full = SpecializationPromptFactory.sessionGuidance(.iOS, mode: mode)
      let compact = SpecializationPromptFactory.compactGuidance(.iOS, mode: mode)
      let grading = SpecializationPromptFactory.evaluationGuidance(.iOS, mode: mode)
      #expect(!full.isEmpty)
      #expect(!compact.isEmpty)
      #expect(!grading.isEmpty)
      // Compact stays a fraction of the full block for local models.
      #expect(compact.count < full.count)
    }
  }

  @Test
  func iOSCodingModesDemandSwiftLanguageHint() {
    for mode in [SessionMode.mockInterview, .drill, .practice] {
      let full = SpecializationPromptFactory.sessionGuidance(.iOS, mode: mode)
      #expect(full.contains("\"swift\""))
      let compact = SpecializationPromptFactory.compactGuidance(.iOS, mode: mode)
      #expect(compact.localizedCaseInsensitiveContains("swift"))
    }
  }

  @Test
  func iOSMockInterviewFramesClassicAlgorithmsInIOSTerms() {
    let full = SpecializationPromptFactory.sessionGuidance(.iOS, mode: .mockInterview)
    #expect(full.contains("image cache"))
    #expect(full.contains("LRU"))
    #expect(full.contains("ios-"))
  }

  @Test
  func iOSDrillsMixPopQuizWithCodingReps() {
    let full = SpecializationPromptFactory.sessionGuidance(.iOS, mode: .drill)
    #expect(full.contains("pop-quiz"))
    #expect(full.contains("async/await"))
    #expect(full.contains("ios-memory-management"))
  }

  @Test
  func iOSSystemDesignIsMobileClientFlavored() {
    let full = SpecializationPromptFactory.sessionGuidance(.iOS, mode: .systemDesign)
    #expect(full.contains("offline"))
    #expect(full.contains("sd-offline-sync"))
    #expect(full.contains("client architecture"))
  }

  @Test
  func iOSBehavioralDrawsFromMobileTeamLife() {
    let full = SpecializationPromptFactory.sessionGuidance(.iOS, mode: .behavioral)
    #expect(full.contains("App Store"))
    #expect(full.contains("bh-"))
  }
}
