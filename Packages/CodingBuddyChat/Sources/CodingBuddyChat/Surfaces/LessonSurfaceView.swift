//
//  LessonSurfaceView.swift
//  CodingBuddyChat
//
//  The learning session's working surface. Renders the `buddy-lesson` fence
//  the agent emits each turn — one scenario, one cited source, one task — and
//  hosts the learner's response, so the whole loop (read → inspect → answer →
//  feedback → next task) happens here instead of being reconstructed from a
//  wall of chat prose.
//

import CodingBuddyKit
import KnowledgeKit
import SwiftUI

struct LessonSurfaceView: View {
  let lesson: Lesson?
  let item: StudyPlanItem?
  let itemNumber: Int?
  let totalItemCount: Int?
  let studySpaceName: String?
  let isLoading: Bool
  let onSubmitResponse: (String) -> Void
  let onRequestHelp: () -> Void
  let onOpenSource: (Lesson.SourceReference) -> Void
  let onSetCompletion: (Bool) -> Void
  let onStartNextItem: () -> Void
  let onOpenLibrary: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if let lesson {
        lessonBody(lesson)
      } else {
        LessonEmptyStateView(
          isLoading: isLoading,
          studySpaceName: studySpaceName,
          onOpenLibrary: onOpenLibrary
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }

  private func lessonBody(_ lesson: Lesson) -> some View {
    VStack(spacing: 0) {
      LessonHeaderView(
        lesson: lesson,
        title: lessonTitle(lesson),
        itemNumber: itemNumber,
        totalItemCount: totalItemCount,
        isLoading: isLoading,
        onOpenLibrary: onOpenLibrary
      )

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if let feedback = lesson.feedbackMarkdown {
            LessonFeedbackCard(feedback: feedback, teaches: lesson.teachesMarkdown)
          }

          if !lesson.outcome.isEmpty {
            LessonOutcomeCard(
              outcome: lesson.outcome,
              whyMarkdown: lesson.whyMarkdown,
              startsExpanded: lesson.isOpeningTurn
            )
            .id("outcome-\(lesson.id)")
          }

          if let source = lesson.source {
            LessonSourceCard(source: source, onOpen: onOpenSource)
          }

          if !lesson.scenarioMarkdown.isEmpty || !lesson.inspectSteps.isEmpty {
            LessonTaskCard(
              scenarioMarkdown: lesson.scenarioMarkdown,
              inspectSteps: lesson.inspectSteps
            )
          }

          if lesson.isClosingTurn {
            LessonWrapUpCard(
              isItemComplete: lesson.isItemComplete,
              isItemCompleted: item?.isCompleted ?? false,
              canToggleCompletion: item != nil,
              isLoading: isLoading,
              onSetCompletion: onSetCompletion,
              onStartNextItem: onStartNextItem
            )
          } else {
            LessonResponseEditor(
              lesson: lesson,
              isItemCompleted: item?.isCompleted ?? false,
              canToggleCompletion: item != nil,
              isLoading: isLoading,
              onSubmit: onSubmitResponse,
              onRequestHelp: onRequestHelp,
              onSetCompletion: onSetCompletion
            )
            // A new turn gets a fresh editor: the previous answer is already
            // in the transcript, and the scaffold belongs to this task.
            .id(lesson.id)
          }
        }
        .padding(20)
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func lessonTitle(_ lesson: Lesson) -> String {
    if !lesson.itemTitle.isEmpty { return lesson.itemTitle }
    if let item { return item.title }
    return "Lesson"
  }
}
