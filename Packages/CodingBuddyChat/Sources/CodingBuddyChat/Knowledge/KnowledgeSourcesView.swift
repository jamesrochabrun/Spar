import CodingBuddyKit
import KnowledgeKit
import SwiftUI

public struct KnowledgeSourcesView: View {
  @Bindable private var library: KnowledgeLibraryService
  private let studySpaceID: String?
  private let isLocked: Bool

  @State private var searchText = ""
  @Environment(\.colorScheme) private var colorScheme

  public init(
    library: KnowledgeLibraryService,
    studySpaceID: String?,
    isLocked: Bool = false
  ) {
    self.library = library
    self.studySpaceID = studySpaceID
    self.isLocked = isLocked
  }

  public var body: some View {
    Group {
      if isLocked {
        ContentUnavailableView {
          Label("Sources Hidden", systemImage: "book.closed")
        } description: {
          Text("This is a closed-book interview. Sources become available with the final report.")
        }
      } else if let studySpaceID,
                let studySpace = library.studySpace(id: studySpaceID) {
        sourcesContent(studySpace: studySpace)
      } else {
        ContentUnavailableView {
          Label("No Study Space", systemImage: "books.vertical")
        } description: {
          Text("Choose a Study Space when starting a session to browse grounded sources here.")
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }

  private func sourcesContent(studySpace: StudySpace) -> some View {
    HSplitView {
      VStack(spacing: 0) {
        sourceSearchHeader(studySpace: studySpace)
        Divider()
        resultList
      }
      .frame(minWidth: 240, idealWidth: 300, maxWidth: 380)

      KnowledgeChunkPreview(chunk: library.selectedChunk)
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
    }
    .task(id: studySpace.id) {
      await library.browse(studySpaceID: studySpace.id)
    }
    .task(id: searchText) {
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      await library.search(studySpaceID: studySpace.id, query: searchText)
    }
  }

  private func sourceSearchHeader(studySpace: StudySpace) -> some View {
    VStack(alignment: .leading) {
      Label(studySpace.name, systemImage: "books.vertical")
        .font(.headline)
        .lineLimit(1)

      TextField("Search sources", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Search \(studySpace.name)")
    }
    .padding()
  }

  private var resultList: some View {
    Group {
      if library.latestResults.isEmpty {
        ContentUnavailableView.search
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(library.latestResults) { result in
              resultButton(result)
            }
          }
          .padding(8)
        }
      }
    }
  }

  private func resultButton(_ result: KnowledgeSearchResult) -> some View {
    let isSelected = result.chunk.id == library.selectedChunk?.id
    return Button {
      Task {
        await library.selectChunk(id: result.chunk.id)
      }
    } label: {
      VStack(alignment: .leading, spacing: 3) {
        Text(result.chunk.relativePath)
          .font(.callout.monospaced())
          .lineLimit(1)
          .truncationMode(.middle)
        Text("Lines \(result.chunk.startLine)–\(result.chunk.endLine)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(result.chunk.content)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(8)
      .background(
        isSelected
          ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme)
          : Color.clear,
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(result.chunk.relativePath), lines \(result.chunk.startLine) through \(result.chunk.endLine)")
  }
}

private struct KnowledgeChunkPreview: View {
  let chunk: KnowledgeChunk?

  @State private var previewText = ""
  @State private var documentID = UUID()
  @State private var displayMode: EditorDisplayMode = .highlighted
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if let chunk {
        VStack(spacing: 0) {
          HStack {
            Text(chunk.relativePath)
              .font(.callout.monospaced())
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
            Text("Lines \(chunk.startLine)–\(chunk.endLine)")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal)
          .frame(height: 38)
          .background(EaselDesignSystem.Palette.surface(for: colorScheme))

          Divider()

          SourceCodeEditorView(
            text: $previewText,
            fileName: chunk.relativePath,
            documentID: documentID,
            displayMode: displayMode,
            isEditable: false,
            onTextChange: { _ in },
            onIdleTextSnapshot: { _ in }
          )
        }
        .onAppear {
          load(chunk)
        }
        .onChange(of: chunk.id) { _, _ in
          load(chunk)
        }
      } else {
        ContentUnavailableView {
          Label("Select a Passage", systemImage: "doc.text.magnifyingglass")
        } description: {
          Text("Choose a search result to inspect the exact source Buddy can cite.")
        }
      }
    }
  }

  private func load(_ chunk: KnowledgeChunk) {
    previewText = chunk.content
    displayMode = .displayMode(for: chunk.content)
    documentID = UUID()
  }
}
