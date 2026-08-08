import KnowledgeKit
import SwiftUI

struct StudySpaceLibraryRow: View {
  let studySpace: StudySpace
  let sources: [KnowledgeSource]
  let plan: StudyPlan?
  let onDelete: () -> Void

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "folder.text")
        .imageScale(.large)
        .foregroundStyle(.tint)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(studySpace.name)
          .font(.headline)

        Text(sourceSummary)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(1)

        if let plan {
          ProgressView(value: plan.completionFraction)
            .accessibilityLabel("Learning progress")
            .accessibilityValue("\(plan.completedItemCount) of \(plan.items.count) complete")

          Text("\(plan.completedItemCount) of \(plan.items.count) complete")
            .font(.callout)
            .foregroundStyle(.secondary)
        } else if isReady {
          Text("Ready to create a learning plan")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 4)

      Menu("Repository Actions", systemImage: "ellipsis.circle") {
        Button("Delete Repository", systemImage: "trash", role: .destructive, action: onDelete)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
    }
    .padding(.vertical, 4)
  }

  private var isReady: Bool {
    sources.contains { $0.indexStatus == .ready && $0.chunkCount > 0 }
  }

  private var sourceSummary: String {
    if sources.contains(where: { $0.indexStatus == .failed }) {
      return "Repository inspection failed"
    }
    if sources.contains(where: { $0.indexStatus == .indexing }) {
      return "Inspecting repository…"
    }
    let files = sources.reduce(0) { $0 + $1.indexedFileCount }
    let passages = sources.reduce(0) { $0 + $1.chunkCount }
    return "\(files) files · \(passages) passages"
  }
}
