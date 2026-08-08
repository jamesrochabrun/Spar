import CodingBuddyKit
import KnowledgeKit
import SwiftUI
import UniformTypeIdentifiers

public struct KnowledgeLibraryView: View {
  @Bindable private var library: KnowledgeLibraryService
  private let onStartLearning: (String, ChatService.StudyPlanFocus) -> Void

  @State private var selectedStudySpaceID: String?
  @State private var isRepositoryImporterPresented = false
  @State private var isDeleteConfirmationPresented = false
  @State private var studySpaceToDelete: StudySpace?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  public init(
    library: KnowledgeLibraryService,
    onStartLearning: @escaping (String, ChatService.StudyPlanFocus) -> Void
  ) {
    self.library = library
    self.onStartLearning = onStartLearning
  }

  public var body: some View {
    NavigationSplitView {
      LearningLibrarySidebar(
        library: library,
        selectedStudySpaceID: $selectedStudySpaceID,
        onAddRepository: presentRepositoryImporter,
        onDelete: presentDeleteConfirmation
      )
      .navigationTitle("Learning Library")
      .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
    } detail: {
      if let selectedStudySpace {
        StudySpaceLearningDetailView(
          library: library,
          studySpace: selectedStudySpace,
          onStartLearning: startLearning
        )
      } else {
        ContentUnavailableView {
          Label("Select a Repository", systemImage: "folder.text")
        } description: {
          Text("Choose a repository to inspect its sources and learning checklist.")
        } actions: {
          Button("Add Repository", systemImage: "folder.badge.plus", action: presentRepositoryImporter)
            .buttonStyle(.borderedProminent)
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Done", action: dismiss.callAsFunction)
      }
      ToolbarItem(placement: .primaryAction) {
        Button("Add Repository", systemImage: "folder.badge.plus", action: presentRepositoryImporter)
          .disabled(library.isImporting)
      }
    }
    .frame(minWidth: 820, idealWidth: 980, minHeight: 540, idealHeight: 680)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .fileImporter(
      isPresented: $isRepositoryImporterPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false,
      onCompletion: importRepository
    )
    .alert(
      "Delete Repository?",
      isPresented: $isDeleteConfirmationPresented,
      presenting: studySpaceToDelete
    ) { studySpace in
      Button("Cancel", role: .cancel, action: clearDeleteConfirmation)
      Button("Delete", role: .destructive) {
        deleteStudySpace(studySpace)
      }
    } message: { studySpace in
      Text(
        "This removes “\(studySpace.name)”, its learning plan, and its local search index. The original repository is not changed."
      )
    }
    .task {
      await library.load()
      reconcileSelection()
    }
    .onChange(of: library.studySpaces.map(\.id)) {
      reconcileSelection()
    }
  }

  private var selectedStudySpace: StudySpace? {
    library.studySpace(id: selectedStudySpaceID)
  }

  private func presentRepositoryImporter() {
    isRepositoryImporterPresented = true
  }

  private func presentDeleteConfirmation(_ studySpace: StudySpace) {
    studySpaceToDelete = studySpace
    isDeleteConfirmationPresented = true
  }

  private func clearDeleteConfirmation() {
    studySpaceToDelete = nil
  }

  private func deleteStudySpace(_ studySpace: StudySpace) {
    Task {
      await library.deleteStudySpace(studySpace)
      clearDeleteConfirmation()
      reconcileSelection()
    }
  }

  private func importRepository(_ result: Result<[URL], Error>) {
    guard case .success(let urls) = result, let repositoryURL = urls.first else {
      return
    }
    Task {
      if let studySpace = await library.addRepository(at: repositoryURL) {
        selectedStudySpaceID = studySpace.id
      }
    }
  }

  private func reconcileSelection() {
    guard library.studySpace(id: selectedStudySpaceID) == nil else { return }
    selectedStudySpaceID = library.studyPlans.first?.studySpaceID ?? library.studySpaces.first?.id
  }

  private func startLearning(_ focus: ChatService.StudyPlanFocus) {
    guard let selectedStudySpaceID else { return }
    onStartLearning(selectedStudySpaceID, focus)
    dismiss()
  }
}
