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
  func sourceBackedSessionsKeepWorkspaceFirstAndDefault() {
    let regular = StudioSurface.available(for: .mockInterview)
    let grounded = StudioSurface.available(for: .mockInterview, includesSources: true)

    #expect(!regular.contains(.sources))
    // The working surface stays first; Sources slots in right after it.
    #expect(grounded.first == .workspace)
    #expect(grounded[1] == .sources)
    // Grounded sessions still open on the workspace, never on Sources.
    #expect(StudioSurface.defaultSurface(for: .practice) == .workspace)
    #expect(StudioSurface.defaultSurface(for: .mockInterview) == .workspace)

    let groundedSystemDesign = StudioSurface.available(for: .systemDesign, includesSources: true)
    #expect(groundedSystemDesign.first == .whiteboard)
    #expect(groundedSystemDesign[1] == .sources)
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
