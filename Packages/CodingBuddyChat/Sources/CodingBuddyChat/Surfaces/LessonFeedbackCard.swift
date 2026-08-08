//
//  LessonFeedbackCard.swift
//  CodingBuddyChat
//

import CodingBuddyKit
import SwiftUI

/// The response to what the learner just said, plus the one thing their
/// observation reveals. Absent on an item's opening turn.
struct LessonFeedbackCard: View {
  let feedback: String
  let teaches: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LessonSectionLabel(
        title: "Feedback",
        systemImage: "bubble.left.and.text.bubble.right"
      )

      Text(LessonMarkdown.inline(feedback))
        .font(.system(size: 13))
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)

      if let teaches {
        Divider()

        VStack(alignment: .leading, spacing: 6) {
          LessonSectionLabel(title: "What this teaches", systemImage: "lightbulb")

          Text(LessonMarkdown.inline(teaches))
            .font(.system(size: 13))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(LessonCardBackground())
  }
}
