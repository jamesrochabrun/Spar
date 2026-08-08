//
//  LessonPanelView.swift
//  CodingBuddyChat
//
//  Public entry point for the Lesson surface: binds `LessonSurfaceView` (a
//  pure render of one `buddy-lesson` turn) to the chat service that produces
//  and consumes those turns.
//

import SwiftUI

public struct LessonPanelView: View {
  private let chatService: ChatService
  private let onOpenLibrary: () -> Void

  public init(chatService: ChatService, onOpenLibrary: @escaping () -> Void) {
    self.chatService = chatService
    self.onOpenLibrary = onOpenLibrary
  }

  public var body: some View {
    LessonSurfaceView(
      lesson: chatService.currentLesson,
      item: chatService.currentLessonItem,
      itemNumber: chatService.currentLessonItemNumber,
      totalItemCount: chatService.currentStudyPlan?.items.count,
      studySpaceName: chatService.currentStudySpaceName,
      isLoading: chatService.isLessonLoading,
      onSubmitResponse: chatService.submitLessonResponse,
      onRequestHelp: chatService.requestLessonHelp,
      onOpenSource: { source in
        Task { await chatService.openLessonSource(source) }
      },
      onSetCompletion: { isCompleted in
        Task { await chatService.setCurrentLessonItemCompletion(isCompleted) }
      },
      onStartNextItem: {
        Task { await chatService.startNextLessonItem() }
      },
      onOpenLibrary: onOpenLibrary
    )
  }
}
