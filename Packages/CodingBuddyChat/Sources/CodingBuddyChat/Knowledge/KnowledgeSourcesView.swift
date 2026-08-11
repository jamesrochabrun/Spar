import CodingBuddyKit
import KnowledgeKit
import SwiftUI

/// Right-panel surface for a source-grounded session: search/browse the study
/// space's indexed passages, inspect exactly what Spar retrieved for its last
/// turn, and preview any passage in a read-only editor.
public struct KnowledgeSourcesView: View {
  @Bindable private var library: KnowledgeLibraryService
  private let studySpaceID: String?
  private let isLocked: Bool

  @State private var searchText = ""
  @State private var scope: SourceScope = .library
  @Environment(\.colorScheme) private var colorScheme

  private enum SourceScope: String, CaseIterable, Identifiable {
    case library
    case retrieved

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .library: return "Library"
      case .retrieved: return "Sent to \(AppBrand.name)"
      }
    }
  }

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
        header(studySpace: studySpace)
        Divider()
        switch scope {
        case .library:
          libraryResultList
        case .retrieved:
          retrievedList
        }
        Spacer(minLength: 0)
      }
      .frame(minWidth: 260, idealWidth: 320, maxWidth: 360)
      .frame(maxHeight: .infinity, alignment: .top)

      KnowledgeChunkPreview(chunk: library.selectedChunk)
        .frame(
          minWidth: 440,
          idealWidth: 640,
          maxWidth: .infinity,
          maxHeight: .infinity
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .task(id: LibraryQuery(studySpaceID: studySpace.id, searchText: searchText)) {
      if !searchText.isEmpty {
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
      }
      await library.search(studySpaceID: studySpace.id, query: searchText)
    }
  }

  private struct LibraryQuery: Equatable {
    let studySpaceID: String
    let searchText: String
  }

  // MARK: - Header

  private func header(studySpace: StudySpace) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label(studySpace.name, systemImage: "books.vertical")
          .font(.headline)
          .lineLimit(1)

        Spacer()

        Text(indexSummary(studySpace: studySpace))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Picker("Source scope", selection: $scope) {
        ForEach(SourceScope.allCases) { scope in
          Text(scope.displayName).tag(scope)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if scope == .library {
        searchField(studySpace: studySpace)
      }
    }
    .padding(12)
  }

  private func searchField(studySpace: StudySpace) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      TextField("Search passages", text: $searchText)
        .textFieldStyle(.plain)
        .accessibilityLabel("Search \(studySpace.name)")

      if !searchText.isEmpty {
        Button("Clear Search", systemImage: "xmark.circle.fill") {
          searchText = ""
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
      in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
    )
  }

  private func indexSummary(studySpace: StudySpace) -> String {
    let sources = library.sources(studySpaceID: studySpace.id)
    let passages = sources.reduce(0) { $0 + $1.chunkCount }
    return "\(passages) passages"
  }

  // MARK: - Library results

  private var libraryResultList: some View {
    Group {
      if library.latestResults.isEmpty {
        if searchText.isEmpty {
          ContentUnavailableView {
            Label("Nothing Indexed Yet", systemImage: "tray")
          } description: {
            Text("This study space has no searchable passages.")
          }
        } else {
          ContentUnavailableView.search(text: searchText)
        }
      } else {
        VStack(alignment: .leading, spacing: 0) {
          Text(resultCountText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

          resultScrollList(library.latestResults)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var resultCountText: String {
    let count = library.latestResults.count
    if searchText.isEmpty {
      return count == 1 ? "1 passage" : "\(count) passages"
    }
    return count == 1 ? "1 match" : "\(count) matches"
  }

  // MARK: - Retrieved-context results

  private var retrievedList: some View {
    Group {
      if library.lastRetrieval.isEmpty {
        ContentUnavailableView {
          Label("No Retrieval Yet", systemImage: "arrow.up.doc")
        } description: {
          Text("When you send a message, the passages \(AppBrand.name) receives as grounding context appear here.")
        }
      } else {
        VStack(alignment: .leading, spacing: 0) {
          Text("Passages sent with the last message")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

          resultScrollList(library.lastRetrieval)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Shared result list

  private func resultScrollList(_ results: [KnowledgeSearchResult]) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 2) {
        ForEach(results) { result in
          resultButton(result)
        }
      }
      .padding(8)
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
        HStack(spacing: 6) {
          Text(fileName(for: result.chunk))
            .font(.callout.weight(.medium).monospaced())
            .lineLimit(1)

          Spacer(minLength: 0)

          Text("L\(result.chunk.startLine)–\(result.chunk.endLine)")
            .font(.caption2.monospaced())
            .foregroundStyle(.tertiary)
        }

        if let directory = directoryPath(for: result.chunk) {
          Text(directory)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Text(highlightedSnippet(for: result.chunk))
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

  private func fileName(for chunk: KnowledgeChunk) -> String {
    let name = (chunk.relativePath as NSString).lastPathComponent
    return name.isEmpty ? chunk.relativePath : name
  }

  private func directoryPath(for chunk: KnowledgeChunk) -> String? {
    let directory = (chunk.relativePath as NSString).deletingLastPathComponent
    return directory.isEmpty ? nil : directory
  }

  /// Two-line snippet centered on the first search match, with matched terms
  /// emphasized. Falls back to the start of the passage when browsing.
  private func highlightedSnippet(for chunk: KnowledgeChunk) -> AttributedString {
    let terms = searchTerms
    let snippet = Self.snippet(from: chunk.content, around: terms)
    var attributed = AttributedString(snippet)

    for term in terms {
      var searchStart = attributed.startIndex
      while let range = attributed[searchStart...].range(
        of: term,
        options: [.caseInsensitive, .diacriticInsensitive]
      ) {
        attributed[range].inlinePresentationIntent = .stronglyEmphasized
        attributed[range].foregroundColor = EaselDesignSystem.Palette.accent
        searchStart = range.upperBound
      }
    }
    return attributed
  }

  private var searchTerms: [String] {
    guard scope == .library else { return [] }
    return searchText
      .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
      .filter { !$0.isEmpty }
  }

  private static func snippet(from content: String, around terms: [String]) -> String {
    let flattened = content
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let firstTerm = terms.first(where: { flattened.range(of: $0, options: .caseInsensitive) != nil }),
          let matchRange = flattened.range(of: firstTerm, options: .caseInsensitive) else {
      return String(flattened.prefix(160))
    }

    let start = flattened.index(
      matchRange.lowerBound,
      offsetBy: -60,
      limitedBy: flattened.startIndex
    ) ?? flattened.startIndex
    let end = flattened.index(
      start,
      offsetBy: 160,
      limitedBy: flattened.endIndex
    ) ?? flattened.endIndex
    let prefix = start > flattened.startIndex ? "…" : ""
    return prefix + flattened[start..<end]
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
          Text("Choose a search result to inspect the exact source \(AppBrand.name) can cite.")
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
