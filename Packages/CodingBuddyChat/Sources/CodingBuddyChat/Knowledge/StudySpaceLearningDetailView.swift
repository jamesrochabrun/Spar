import CodingBuddyKit
import KnowledgeKit
import SwiftUI

struct StudySpaceLearningDetailView: View {
  @Bindable var library: KnowledgeLibraryService
  let studySpace: StudySpace
  let onStartLearning: (ChatService.StudyPlanFocus) -> Void

  @State private var selectedSection: StudySpaceLearningSection = .plan
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
        Image(systemName: "folder.text")
          .font(.title2)
          .foregroundStyle(.tint)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(studySpace.name)
            .font(.title2)
            .bold()

          Text(repositorySummary)
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if let plan {
          Text("\(plan.completedItemCount) / \(plan.items.count) complete")
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      .padding()

      Picker("Repository section", selection: $selectedSection) {
        ForEach(StudySpaceLearningSection.allCases) { section in
          Text(section.displayName).tag(section)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: 320)
      .padding(.horizontal)
      .padding(.bottom)

      Divider()

      switch selectedSection {
      case .plan:
        RepositoryStudyPlanView(
          library: library,
          studySpace: studySpace,
          plan: plan,
          onStartLearning: onStartLearning
        )
      case .sources:
        KnowledgeSourcesView(
          library: library,
          studySpaceID: studySpace.id
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }

  private var plan: StudyPlan? {
    library.studyPlan(studySpaceID: studySpace.id)
  }

  private var repositorySummary: String {
    let sources = library.sources(studySpaceID: studySpace.id)
    let files = sources.reduce(0) { $0 + $1.indexedFileCount }
    let passages = sources.reduce(0) { $0 + $1.chunkCount }
    return "\(files) indexed files · \(passages) searchable passages"
  }
}
