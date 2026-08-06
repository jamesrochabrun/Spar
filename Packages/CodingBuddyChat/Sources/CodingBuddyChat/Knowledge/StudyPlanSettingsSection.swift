import KnowledgeKit
import SwiftUI

struct StudyPlanSettingsSection: View {
  @Bindable private var library: KnowledgeLibraryService
  private let chatService: ChatService
  @State private var selectedStudySpaceID: String?

  init(library: KnowledgeLibraryService, chatService: ChatService) {
    self.library = library
    self.chatService = chatService
    self._selectedStudySpaceID = State(initialValue: library.studyPlans.first?.studySpaceID)
  }

  var body: some View {
    Section("Study Plans") {
      if library.studyPlans.isEmpty {
        ContentUnavailableView(
          "No Study Plans",
          systemImage: "checklist",
          description: Text("Start a Learn session with a repository to create a structured plan.")
        )
      } else {
        Picker("Repository", selection: $selectedStudySpaceID) {
          ForEach(library.studyPlans) { plan in
            Text(library.studySpace(id: plan.studySpaceID)?.name ?? plan.title)
              .tag(Optional(plan.studySpaceID))
          }
        }

        if let selectedPlan {
          HStack {
            Button("Continue", systemImage: "play.fill", action: continueLearning)
              .buttonStyle(.borderedProminent)

            Button("Random Topic", systemImage: "shuffle", action: studyRandomTopic)
          }

          StudyPlanChecklistView(
            plan: selectedPlan,
            onCompletionChange: updateCompletion,
            onStudy: study
          )
        }
      }

      if let errorMessage = library.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
      }
    }
    .task {
      await library.load()
      reconcileSelection()
    }
    .onChange(of: library.studyPlans.map(\.studySpaceID)) {
      reconcileSelection()
    }
  }

  private var selectedPlan: StudyPlan? {
    library.studyPlan(studySpaceID: selectedStudySpaceID)
  }

  private func reconcileSelection() {
    guard library.studyPlan(studySpaceID: selectedStudySpaceID) == nil else { return }
    selectedStudySpaceID = library.studyPlans.first?.studySpaceID
  }

  private func continueLearning() {
    guard let selectedPlan else { return }
    Task {
      await chatService.startLearning(studySpaceID: selectedPlan.studySpaceID, focus: .next)
    }
  }

  private func studyRandomTopic() {
    guard let selectedPlan else { return }
    Task {
      await chatService.startLearning(studySpaceID: selectedPlan.studySpaceID, focus: .random)
    }
  }

  private func study(_ item: StudyPlanItem) {
    guard let selectedPlan else { return }
    Task {
      await chatService.startLearning(
        studySpaceID: selectedPlan.studySpaceID,
        focus: .item(item.id)
      )
    }
  }

  private func updateCompletion(_ item: StudyPlanItem, isCompleted: Bool) {
    guard let selectedPlan else { return }
    Task {
      await library.setStudyPlanItemCompletion(
        planID: selectedPlan.id,
        itemID: item.id,
        isCompleted: isCompleted
      )
    }
  }
}
