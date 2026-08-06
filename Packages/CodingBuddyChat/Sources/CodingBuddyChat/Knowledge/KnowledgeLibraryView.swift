import CodingBuddyKit
import KnowledgeKit
import SwiftUI
import UniformTypeIdentifiers

public struct KnowledgeLibraryView: View {
  @Bindable private var library: KnowledgeLibraryService

  @State private var isRepositoryImporterPresented = false
  @State private var isDeleteConfirmationPresented = false
  @State private var studySpaceToDelete: StudySpace?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  public init(library: KnowledgeLibraryService) {
    self.library = library
  }

  public var body: some View {
    NavigationStack {
      Group {
        if library.studySpaces.isEmpty, !library.isImporting {
          ContentUnavailableView {
            Label("No Study Spaces", systemImage: "books.vertical")
          } description: {
            Text("Add a repository to ask grounded questions and start source-based interviews.")
          } actions: {
            Button("Add Repository", systemImage: "folder.badge.plus") {
              isRepositoryImporterPresented = true
            }
            .buttonStyle(.borderedProminent)
          }
        } else {
          studySpaceList
        }
      }
      .navigationTitle("Study Spaces")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done", action: dismiss.callAsFunction)
        }
        ToolbarItem(placement: .primaryAction) {
          Button("Add Repository", systemImage: "folder.badge.plus") {
            isRepositoryImporterPresented = true
          }
          .disabled(library.isImporting)
        }
      }
    }
    .frame(minWidth: 620, idealWidth: 760, minHeight: 420, idealHeight: 560)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .fileImporter(
      isPresented: $isRepositoryImporterPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false,
      onCompletion: importRepository
    )
    .alert(
      "Delete Study Space?",
      isPresented: $isDeleteConfirmationPresented,
      presenting: studySpaceToDelete
    ) { studySpace in
      Button("Cancel", role: .cancel) {
        studySpaceToDelete = nil
      }
      Button("Delete", role: .destructive) {
        Task {
          await library.deleteStudySpace(studySpace)
          studySpaceToDelete = nil
        }
      }
    } message: { studySpace in
      Text("This removes “\(studySpace.name)” and its local search index. The original repository is not changed.")
    }
    .task {
      await library.load()
    }
  }

  private var studySpaceList: some View {
    List {
      if library.isImporting {
        HStack {
          ProgressView()
            .controlSize(.small)
          Text("Indexing repository…")
          Spacer()
        }
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
          onDelete: {
            studySpaceToDelete = studySpace
            isDeleteConfirmationPresented = true
          }
        )
      }
    }
  }

  private func importRepository(_ result: Result<[URL], Error>) {
    guard case .success(let urls) = result, let repositoryURL = urls.first else {
      return
    }
    Task {
      await library.addRepository(at: repositoryURL)
    }
  }
}

private struct StudySpaceLibraryRow: View {
  let studySpace: StudySpace
  let sources: [KnowledgeSource]
  let onDelete: () -> Void

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "folder.text")
        .imageScale(.large)
        .foregroundStyle(.tint)
        .accessibilityHidden(true)

      VStack(alignment: .leading) {
        Text(studySpace.name)
          .font(.headline)

        ForEach(sources) { source in
          HStack {
            Label(sourceSummary(source), systemImage: statusImage(source.indexStatus))
              .foregroundStyle(statusStyle(source.indexStatus))
            Spacer()
            Text(source.rootPath)
              .foregroundStyle(.tertiary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          .font(.callout)
        }
      }

      Spacer()

      Menu("Study Space Actions", systemImage: "ellipsis.circle") {
        Button("Delete Study Space", systemImage: "trash", role: .destructive, action: onDelete)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
    }
    .padding(.vertical, 4)
  }

  private func sourceSummary(_ source: KnowledgeSource) -> String {
    switch source.indexStatus {
    case .pending: return "Waiting to index"
    case .indexing: return "Indexing \(source.displayName)"
    case .ready:
      return "\(source.indexedFileCount) files · \(source.chunkCount) searchable passages"
    case .failed:
      return source.errorMessage ?? "Indexing failed"
    }
  }

  private func statusImage(_ status: KnowledgeIndexStatus) -> String {
    switch status {
    case .pending: return "clock"
    case .indexing: return "arrow.trianglehead.2.clockwise.rotate.90"
    case .ready: return "checkmark.circle.fill"
    case .failed: return "exclamationmark.triangle.fill"
    }
  }

  private func statusStyle(_ status: KnowledgeIndexStatus) -> HierarchicalShapeStyle {
    switch status {
    case .ready: return .secondary
    case .pending, .indexing, .failed: return .primary
    }
  }
}
