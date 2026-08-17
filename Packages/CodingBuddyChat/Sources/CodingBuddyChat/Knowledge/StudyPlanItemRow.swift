import CodingBuddyKit
import KnowledgeKit
import SwiftUI

struct StudyPlanItemRow: View {
  let number: Int
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

      Text("\(number).")
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(minWidth: 22, alignment: .trailing)
        .accessibilityHidden(true)

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

      Button("Start", systemImage: "play.fill", action: onStudy)
        .easelSecondaryButton()
        .controlSize(.small)
        .help("Open item \(number) in the Lesson panel — \(AppBrand.name) sets the first task")
    }
    .padding(.vertical, 4)
  }

  private func toggleCompletion() {
    onCompletionChange(!item.isCompleted)
  }
}
