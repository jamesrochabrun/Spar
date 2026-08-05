//
//  InterviewSpecializationTests.swift
//  InterviewKitTests
//

import Testing
@testable import InterviewKit

struct InterviewSpecializationTests {

  @Test
  func defaultTrackIsiOS() {
    #expect(InterviewSpecialization.default == .iOS)
  }

  @Test
  func rawValuesAreStableForPersistence() {
    #expect(InterviewSpecialization.iOS.rawValue == "ios")
    #expect(InterviewSpecialization.general.rawValue == "general")
  }

  @Test
  func everyCaseIsPresentable() {
    for specialization in InterviewSpecialization.allCases {
      #expect(!specialization.displayName.isEmpty)
      #expect(!specialization.systemImage.isEmpty)
      #expect(!specialization.summary.isEmpty)
      #expect(InterviewSpecialization(rawValue: specialization.id) == specialization)
    }
  }
}
