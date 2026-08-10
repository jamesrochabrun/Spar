//
//  SessionModeBriefTests.swift
//  InterviewKitTests
//

import Foundation
import Testing
@testable import InterviewKit

struct SessionModeBriefTests {

  @Test
  func everyModeExplainsItself() {
    for mode in SessionMode.allCases {
      let brief = mode.brief
      #expect(!brief.format.isEmpty)
      #expect(!brief.feedback.isEmpty)
      #expect(!brief.bestFor.isEmpty)
      #expect(!mode.usageSubtitle.isEmpty)
    }
  }

  @Test
  func briefsAreDistinctSoThePickerNeverRepeatsItself() {
    let formats = Set(SessionMode.allCases.map(\.brief.format))
    let feedback = Set(SessionMode.allCases.map(\.brief.feedback))
    #expect(formats.count == SessionMode.allCases.count)
    #expect(feedback.count == SessionMode.allCases.count)
  }

  @Test
  func mockAndDrillDifferOnTheFeedbackAxis() {
    // The distinction that justifies both modes existing: deferred verdict
    // versus a verdict after every rep.
    #expect(SessionMode.mockInterview.brief.feedback.localizedCaseInsensitiveContains("end"))
    #expect(SessionMode.drill.brief.feedback.localizedCaseInsensitiveContains("instant"))
    #expect(SessionMode.practice.brief.format.localizedCaseInsensitiveContains("untimed"))
  }
}
