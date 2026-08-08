import KnowledgeKit
import SwiftUI

struct LearningLibrarySidebar: View {
  @Bindable var library: KnowledgeLibraryService
  @Binding var selectedStudySpaceID: String?
  let onAddRepository: () -> Void
  let onDelete: (StudySpace) -> Void

  var body: some View {
    Group {
      if library.studySpaces.isEmpty, !library.isImporting {
        ContentUnavailableView {
          Label("No Repositories", systemImage: "books.vertical")
        } description: {
          Text("Add a repository to build a reusable learning checklist.")
        } actions: {
          Button("Add Repository", systemImage: "folder.badge.plus", action: onAddRepository)
            .buttonStyle(.borderedProminent)
        }
      } else {
        List(selection: $selectedStudySpaceID) {
          if library.isImporting {
            Label("Inspecting repository…", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
              .foregroundStyle(.secondary)
              .accessibilityElement(children: .combine)
          }

          if let errorMessage = library.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }

          ForEach(library.studySpaces) { studySpace in
            StudySpaceLibraryRow(
              studySpace: studySpace,
              sources: library.sources(studySpaceID: studySpace.id),
              plan: library.studyPlan(studySpaceID: studySpace.id),
              onDelete: { onDelete(studySpace) }
            )
            .tag(studySpace.id)
          }
        }
      }
    }
  }
}
