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
