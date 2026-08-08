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
      .accessibilityValue("\(plan.completedItemCount) of \(plan.items.count) complete")

      ForEach(sections, id: \.self) { section in
        VStack(alignment: .leading, spacing: 8) {
          Text(section)
            .font(.headline)
            .padding(.top, 8)

          ForEach(plan.items.filter { $0.section == section }) { item in
            StudyPlanItemRow(
              number: itemNumber(item),
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

  private func itemNumber(_ item: StudyPlanItem) -> Int {
    (plan.items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
  }

  private var sections: [String] {
    var seen: Set<String> = []
    return plan.items.compactMap { item in
      guard seen.insert(item.section).inserted else { return nil }
      return item.section
    }
  }
}
