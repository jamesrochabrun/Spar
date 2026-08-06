//
//  SessionSurfacePresentationTests.swift
//  CodingBuddyChatTests
//

import InterviewKit
import Testing
@testable import CodingBuddyChat

struct SessionSurfacePresentationTests {
  @Test
  func codingModesUseFloatingHintsInsteadOfHintsSurface() {
    for mode in [SessionMode.mockInterview, .drill, .practice] {
      let surfaces = StudioSurface.available(for: mode)

      #expect(surfaces.contains(.workspace))
      #expect(!surfaces.contains(.hints))
      #expect(surfaces.contains(.report))
    }
  }

  @Test
  func sourceBackedSessionsAddSourcesWithoutChangingExistingDefaults() {
    let regular = StudioSurface.available(for: .mockInterview)
    let grounded = StudioSurface.available(for: .mockInterview, includesSources: true)

    #expect(!regular.contains(.sources))
    #expect(grounded.first == .sources)
    #expect(grounded.contains(.workspace))
    #expect(StudioSurface.defaultSurface(for: .practice, prefersSources: true) == .sources)
  }

  @Test
  func awaitingEvaluationShowsGradingProgress() {
    let presentation = SessionReportPresentation.resolve(
      hasEvaluation: false,
      attemptStatus: .awaitingEvaluation
    )

    #expect(presentation == .grading)
  }

  @Test
  func requestedEvaluationShowsProgressBeforeStatusTransitionCompletes() {
    let presentation = SessionReportPresentation.resolve(
      hasEvaluation: false,
      attemptStatus: .inProgress,
      isGenerating: true
    )

    #expect(presentation == .grading)
  }

  @Test
  func evaluationTakesPriorityOverAttemptStatus() {
    let presentation = SessionReportPresentation.resolve(
      hasEvaluation: true,
      attemptStatus: .awaitingEvaluation
    )

    #expect(presentation == .evaluation)
  }
}
