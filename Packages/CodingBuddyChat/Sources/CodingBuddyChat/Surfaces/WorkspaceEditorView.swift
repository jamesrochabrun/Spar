//
//  WorkspaceEditorView.swift
//  CodingBuddyChat
//
//  Workspace surface: a lightweight file list over the attempt workspace
//  directory plus the native CodeEdit-based editor pane.
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

public struct WorkspaceEditorView: View {
  private let workspacePath: String?
  private let question: Question?

  @State private var files: [WorkspaceFile] = []
  @State private var selectedFile: WorkspaceFile?
  @State private var fileContent: String = ""
  @State private var isSaving = false
  @State private var loadError: String?
  @State private var isProblemExpanded = true
  @Environment(\.colorScheme) private var colorScheme

  public init(workspacePath: String?, question: Question?) {
    self.workspacePath = workspacePath
    self.question = question
  }

  private var languageHint: String? { question?.languageHint }

  struct WorkspaceFile: Identifiable, Equatable {
    let url: URL
    let relativePath: String
    var id: String { relativePath }
    var fileName: String { url.lastPathComponent }
  }

  public var body: some View {
    Group {
      if let workspacePath {
        VStack(spacing: 0) {
          if let question {
            problemHeader(question)

            Rectangle()
              .fill(EaselDesignSystem.Palette.border(for: colorScheme))
              .frame(height: 1)
          }

          content(workspacePath: workspacePath)
        }
      } else {
        ContentUnavailableView {
          Label("No workspace", systemImage: "folder")
        } description: {
          Text("Start a session to get a scratch workspace for your solution.")
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .task(id: workspacePath) {
      refreshFiles()
    }
    .onChange(of: question?.id) { _, _ in
      // A freshly presented question re-opens the statement.
      isProblemExpanded = true
    }
  }

  /// The problem lives with the editor: collapsible statement above the code,
  /// so solving never requires flipping tabs.
  private func problemHeader(_ question: Question) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Button {
        withAnimation(.easeInOut(duration: 0.18)) {
          isProblemExpanded.toggle()
        }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
            .rotationEffect(.degrees(isProblemExpanded ? 90 : 0))

          Text(question.title)
            .font(EaselDesignSystem.Typography.interface(size: 14, weight: .semibold))
            .lineLimit(1)

          difficultyChip(question.difficulty)

          Spacer()

          Text("Write your solution below — ⌘S saves; graded on End & Grade")
            .font(.caption2)
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
            .lineLimit(1)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if isProblemExpanded {
        ScrollView {
          Text(promptText(question))
            .font(.system(size: 13))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 180)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  private func difficultyChip(_ difficulty: Difficulty) -> some View {
    let color: Color
    switch difficulty {
    case .easy: color = .green
    case .medium: color = .orange
    case .hard: color = .red
    }
    return Text(difficulty.displayName)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(Capsule().fill(color.opacity(0.15)))
  }

  private func promptText(_ question: Question) -> AttributedString {
    (try? AttributedString(
      markdown: question.promptMarkdown,
      options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(question.promptMarkdown)
  }

  @ViewBuilder
  private func content(workspacePath: String) -> some View {
    if files.isEmpty {
      ContentUnavailableView {
        Label("Empty workspace", systemImage: "folder")
      } description: {
        Text("Create a solution file and write your code here. Save with ⌘S — Buddy grades these files when you End & Grade.")
      } actions: {
        Button("Create \(starterFileName)") {
          createStarterFile(in: workspacePath)
        }
        .buttonStyle(.borderedProminent)

        Button("Refresh") {
          refreshFiles()
        }
      }
    } else {
      HStack(spacing: 0) {
        fileList

        Rectangle()
          .fill(EaselDesignSystem.Palette.border(for: colorScheme))
          .frame(width: 1)

        editorPane
      }
    }
  }

  private var fileList: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text("Files")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        Spacer()

        Button {
          refreshFiles()
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 10, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help("Refresh files")
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 1) {
          ForEach(files) { file in
            fileRow(file)
          }
        }
        .padding(.horizontal, 6)
      }

      Spacer(minLength: 0)
    }
    .frame(width: 180)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  private func fileRow(_ file: WorkspaceFile) -> some View {
    let isSelected = selectedFile == file
    return Button {
      select(file)
    } label: {
      HStack(spacing: 5) {
        Image(systemName: "doc")
          .font(.system(size: 10))
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))

        Text(file.relativePath)
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(isSelected ? Color.primary : EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isSelected ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme) : Color.clear,
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var editorPane: some View {
    if let selectedFile {
      ProjectResourceTextPreview(
        fileName: selectedFile.fileName,
        text: fileContent,
        isSaving: isSaving,
        onSave: { newText in
          save(newText, to: selectedFile)
        }
      )
      .id(selectedFile.id)
    } else {
      ContentUnavailableView {
        Label("Select a file", systemImage: "doc.text")
      } description: {
        Text(loadError ?? "Pick a file from the list to edit it.")
      }
    }
  }

  // MARK: - File operations

  private func refreshFiles() {
    guard let workspacePath else {
      files = []
      return
    }

    let rootURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
    var found: [WorkspaceFile] = []
    if let enumerator = FileManager.default.enumerator(
      at: rootURL,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) {
      for case let fileURL as URL in enumerator {
        let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values?.isRegularFile == true else { continue }
        let relativePath = fileURL.path.hasPrefix(rootURL.path + "/")
          ? String(fileURL.path.dropFirst(rootURL.path.count + 1))
          : fileURL.lastPathComponent
        found.append(WorkspaceFile(url: fileURL, relativePath: relativePath))
        if found.count >= 200 { break }
      }
    }
    files = found.sorted { $0.relativePath < $1.relativePath }

    if let selectedFile, !files.contains(selectedFile) {
      self.selectedFile = nil
      fileContent = ""
    }
    if selectedFile == nil, let first = files.first {
      select(first)
    }
  }

  private func select(_ file: WorkspaceFile) {
    do {
      fileContent = try String(contentsOf: file.url, encoding: .utf8)
      selectedFile = file
      loadError = nil
    } catch {
      loadError = "Could not read \(file.fileName): \(error.localizedDescription)"
      selectedFile = nil
      fileContent = ""
    }
  }

  private func save(_ text: String, to file: WorkspaceFile) {
    isSaving = true
    defer { isSaving = false }
    do {
      try text.write(to: file.url, atomically: true, encoding: .utf8)
      fileContent = text
    } catch {
      loadError = "Could not save \(file.fileName): \(error.localizedDescription)"
    }
  }

  private var starterFileName: String {
    switch languageHint?.lowercased() {
    case "python": return "solution.py"
    case "typescript": return "solution.ts"
    case "javascript": return "solution.js"
    case "kotlin": return "Solution.kt"
    case "java": return "Solution.java"
    case "c++", "cpp": return "solution.cpp"
    case "go": return "solution.go"
    case "rust": return "solution.rs"
    default: return "solution.swift"
    }
  }

  private func createStarterFile(in workspacePath: String) {
    let url = URL(fileURLWithPath: workspacePath, isDirectory: true)
      .appendingPathComponent(starterFileName)
    if !FileManager.default.fileExists(atPath: url.path) {
      try? "".write(to: url, atomically: true, encoding: .utf8)
    }
    refreshFiles()
    if let created = files.first(where: { $0.fileName == starterFileName }) {
      select(created)
    }
  }
}
