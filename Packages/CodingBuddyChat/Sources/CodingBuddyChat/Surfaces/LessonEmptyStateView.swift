//
//  LessonEmptyStateView.swift
//  CodingBuddyChat
//

import SwiftUI

/// Before the first fence arrives. The loading copy names the repository so a
/// slow first turn reads as work in progress, not a dead panel.
struct LessonEmptyStateView: View {
  let isLoading: Bool
  let studySpaceName: String?
  let onOpenLibrary: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label(
        isLoading ? "Preparing Your Lesson" : "No Lesson Yet",
        systemImage: isLoading ? "hourglass" : "graduationcap"
      )
    } description: {
      Text(description)
    } actions: {
      if !isLoading {
        Button("Open Learning Library", systemImage: "books.vertical", action: onOpenLibrary)
          .buttonStyle(.borderedProminent)
      }
    }
  }

  private var description: String {
    guard isLoading else {
      return "Open Learning Library and start an item — its task, source, and response land here."
    }
    guard let studySpaceName else {
      return "Buddy is building your next task."
    }
    return "Buddy is reading \(studySpaceName) to build your next task."
  }
}
