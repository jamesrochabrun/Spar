import KnowledgeKit
import SwiftUI

struct StudyPlanItemRow: View {
  let item: StudyPlanItem
  let onCompletionChange: (Bool) -> Void
  let onStudy: () -> Void

  var body: some View {
    HStack(alignment: .top) {
      Button(
        item.isCompleted ? "Mark Incomplete" : "Mark Complete",
        systemImage: item.isCompleted ? "checkmark.circle.fill" : "circle",
        action: toggleCompletion
      )
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      .foregroundStyle(item.isCompleted ? .green : .secondary)
      .accessibilityLabel(item.isCompleted ? "Mark \(item.title) incomplete" : "Mark \(item.title) complete")

      VStack(alignment: .leading) {
        Text(item.title)
          .strikethrough(item.isCompleted)
          .foregroundStyle(item.isCompleted ? .secondary : .primary)

        Text(item.objective)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if !item.sourcePaths.isEmpty {
          Label(item.sourcePaths.prefix(2).joined(separator: ", "), systemImage: "doc.text")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
      }

      Spacer()

      Button("Study", systemImage: "book.pages", action: onStudy)
        .controlSize(.small)
    }
    .padding(.vertical, 4)
  }

  private func toggleCompletion() {
    onCompletionChange(!item.isCompleted)
  }
}
