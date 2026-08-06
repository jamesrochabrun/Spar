import KnowledgeKit
import SwiftUI

struct StudyPlanChecklistView: View {
  let plan: StudyPlan
  let onCompletionChange: (StudyPlanItem, Bool) -> Void
  let onStudy: (StudyPlanItem) -> Void

  var body: some View {
    VStack(alignment: .leading) {
      Text(plan.title)
        .font(.headline)

      if !plan.summary.isEmpty {
        Text(plan.summary)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      ProgressView(value: plan.completionFraction) {
        Text("\(plan.completedItemCount) of \(plan.items.count) complete")
          .font(.callout)
      }

      ForEach(sections, id: \.self) { section in
        DisclosureGroup(section) {
          ForEach(plan.items.filter { $0.section == section }) { item in
            StudyPlanItemRow(
              item: item,
              onCompletionChange: { isCompleted in
                onCompletionChange(item, isCompleted)
              },
              onStudy: {
                onStudy(item)
              }
            )
          }
        }
      }
    }
  }

  private var sections: [String] {
    var seen: Set<String> = []
    return plan.items.compactMap { item in
      guard seen.insert(item.section).inserted else { return nil }
      return item.section
    }
  }
}
