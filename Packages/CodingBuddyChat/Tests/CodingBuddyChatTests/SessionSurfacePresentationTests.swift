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
  func codingProjectStaysFocusedOnXcodeAndTheFinalReport() {
    let surfaces = StudioSurface.available(for: .codingProject)

    #expect(surfaces == [.workspace, .report])
    #expect(StudioSurface.defaultSurface(for: .codingProject) == .workspace)
    #expect(StudioSurface.workspace.displayName(for: .codingProject) == "Requirements")
    #expect(StudioSurface.workspace.systemImage(for: .codingProject) == "checklist")
    #expect(StudioSurface.workspace.displayName(for: .mockInterview) == "Workspace")
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
    #expect(!regular.contains(.lesson))
  }

  @Test
  func systemDesignLeadsWithWhiteboardButKeepsTheWorkspace() {
    let surfaces = StudioSurface.available(for: .systemDesign)

    #expect(surfaces.first == .whiteboard)
    #expect(surfaces.contains(.workspace))
    #expect(surfaces.contains(.hints))
    #expect(surfaces.contains(.report))
    #expect(StudioSurface.defaultSurface(for: .systemDesign) == .whiteboard)
  }

  @Test
  func learningSessionsLeadWithTheLessonAndDropTheReport() {
    let learning = StudioSurface.available(
      for: .practice,
      includesSources: true,
      includesLesson: true
    )

    // The lesson is the working surface; Sources sits next to it because every
    // task cites one.
    #expect(learning.first == .lesson)
    #expect(learning[1] == .sources)
    // A learning session never grades, so a permanently empty Report tab would
    // just be dead weight.
    #expect(!learning.contains(.report))
    // No duplicate Sources tab when both flags are on.
    #expect(learning.count(where: { $0 == .sources }) == 1)

    #expect(StudioSurface.defaultSurface(for: .practice, isLearningSession: true) == .lesson)
    // The flag drives it, not the mode: a learning session is always .practice.
    #expect(StudioSurface.defaultSurface(for: .practice) == .workspace)
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
