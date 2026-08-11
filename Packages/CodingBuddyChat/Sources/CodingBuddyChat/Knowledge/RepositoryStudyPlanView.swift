import CodingBuddyKit
import KnowledgeKit
import SwiftUI

struct RepositoryStudyPlanView: View {
  @Bindable var library: KnowledgeLibraryService
  let studySpace: StudySpace
  let plan: StudyPlan?
  let onStartLearning: (ChatService.StudyPlanFocus) -> Void

  var body: some View {
    Group {
      if let plan {
        VStack(spacing: 0) {
          learningStartBar(plan)

          Divider()

          ScrollView {
            StudyPlanChecklistView(
              plan: plan,
              onCompletionChange: updateCompletion,
              onStudy: study
            )
            .padding()
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
          }
        }
      } else if isRepositoryReady {
        ContentUnavailableView {
          Label("No Learning Plan Yet", systemImage: "checklist")
        } description: {
          Text(
            "\(AppBrand.name) has inspected this repository and can turn its architecture, features, and tests into a structured checklist."
          )
        } actions: {
          Button("Create Learning Plan", systemImage: "sparkles", action: createLearningPlan)
            .buttonStyle(.borderedProminent)
        }
      } else {
        ContentUnavailableView {
          Label("Repository Not Ready", systemImage: "clock")
        } description: {
          Text("Wait for repository inspection to finish before creating a learning plan.")
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func learningStartBar(_ plan: StudyPlan) -> some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 3) {
        Text(nextActionHeading(for: plan))
          .font(.headline)

        Text(nextActionDescription(for: plan))
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 12)

      Button("Choose Random", systemImage: "shuffle", action: studyRandomTopic)
        .buttonStyle(.bordered)

      Button(primaryActionTitle(for: plan), systemImage: "play.fill", action: continueLearning)
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
    .background(.bar)
  }

  private var isRepositoryReady: Bool {
    library.sources(studySpaceID: studySpace.id).contains {
      $0.indexStatus == .ready && $0.chunkCount > 0
    }
  }

  private func primaryActionTitle(for plan: StudyPlan) -> String {
    guard let item = plan.nextIncompleteItem,
          let index = plan.items.firstIndex(where: { $0.id == item.id }) else {
      return "Review a Topic"
    }
    return "Start Item \(index + 1)"
  }

  private func nextActionHeading(for plan: StudyPlan) -> String {
    guard let item = plan.nextIncompleteItem else {
      return "Plan complete — revisit any topic"
    }
    return item.title
  }

  private func nextActionDescription(for plan: StudyPlan) -> String {
    if plan.nextIncompleteItem == nil {
      return "\(AppBrand.name) sets one task at a time in the Lesson panel. Your completed checkmarks stay saved."
    }
    return "\(AppBrand.name) opens a source and sets one task at a time in the Lesson panel — or pick any item below."
  }

  private func createLearningPlan() {
    onStartLearning(.next)
  }

  private func continueLearning() {
    onStartLearning(plan?.nextIncompleteItem == nil ? .random : .next)
  }

  private func studyRandomTopic() {
    onStartLearning(.random)
  }

  private func study(_ item: StudyPlanItem) {
    onStartLearning(.item(item.id))
  }

  private func updateCompletion(_ item: StudyPlanItem, isCompleted: Bool) {
    guard let plan else { return }
    Task {
      await library.setStudyPlanItemCompletion(
        planID: plan.id,
        itemID: item.id,
        isCompleted: isCompleted
      )
    }
  }
}
