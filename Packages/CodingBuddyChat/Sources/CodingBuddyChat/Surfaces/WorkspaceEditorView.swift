//
//  WorkspaceEditorView.swift
//  CodingBuddyChat
//
//  Workspace surface: the editor IS the surface. A solution file is created
//  automatically in the attempt workspace and seeded with the problem
//  statement as a comment header, so you read and solve in one place. A file
//  menu appears only when the workspace grows past one file (e.g. Buddy wrote
//  test files).
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
  @Environment(\.colorScheme) private var colorScheme

  public init(workspacePath: String?, question: Question?) {
    self.workspacePath = workspacePath
    self.question = question
  }

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
          workspaceBar

          Rectangle()
            .fill(EaselDesignSystem.Palette.border(for: colorScheme))
            .frame(height: 1)

          editorPane
        }
        .task(id: workspacePath) {
          prepareWorkspace(workspacePath)
        }
        .onChange(of: question?.id) { _, _ in
          // The question often lands after the session starts: seed the still
          // untouched solution file with the problem header when it arrives.
          prepareWorkspace(workspacePath)
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
  }

  // MARK: - Top bar

  private var workspaceBar: some View {
    HStack(spacing: 8) {
      if files.count > 1 {
        Menu {
          ForEach(files) { file in
            Button(file.relativePath) {
              select(file)
            }
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "doc")
              .font(.system(size: 10))
            Text(selectedFile?.relativePath ?? "Select file")
              .font(.system(size: 12, design: .monospaced))
              .lineLimit(1)
              .truncationMode(.middle)
            Image(systemName: "chevron.up.chevron.down")
              .font(.system(size: 8, weight: .semibold))
          }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .fixedSize()
      } else if let selectedFile {
        HStack(spacing: 4) {
          Image(systemName: "doc")
            .font(.system(size: 10))
          Text(selectedFile.fileName)
            .font(.system(size: 12, design: .monospaced))
        }
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      }

      Spacer()

      if let loadError {
        Text(loadError)
          .font(.caption2)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
          .lineLimit(1)
      } else {
        Text("⌘S saves · graded on End & Grade")
          .font(.caption2)
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
      }

      Button {
        if let workspacePath {
          prepareWorkspace(workspacePath)
        }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 10, weight: .medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .help("Reload files from disk")
    }
    .padding(.horizontal, 14)
    .frame(height: 30)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
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
        Label("Preparing workspace…", systemImage: "doc.text")
      } description: {
        Text(loadError ?? "Your solution file opens here automatically.")
      }
    }
  }

  // MARK: - Workspace preparation

  /// Ensures a solution file exists (seeded with the problem statement as a
  /// comment header when the question is known), then opens it.
  private func prepareWorkspace(_ workspacePath: String) {
    refreshFiles(workspacePath)

    let rootURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
    let starterURL = rootURL.appendingPathComponent(starterFileName)
    var didSeed = false

    if files.isEmpty {
      let seed = question.map(seededContent(for:)) ?? ""
      try? seed.write(to: starterURL, atomically: true, encoding: .utf8)
      refreshFiles(workspacePath)
      didSeed = true
    } else if let question,
              let starter = files.first(where: { $0.url == starterURL }),
              let existing = try? String(contentsOf: starter.url, encoding: .utf8),
              existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      // Question arrived after the file was created and it's still untouched
      // on disk AND in the visible buffer: seed it now. Never overwrite
      // anything the candidate typed.
      try? seededContent(for: question).write(to: starter.url, atomically: true, encoding: .utf8)
      didSeed = true
    }

    // Prefer the solution file; fall back to the first file. Only reload an
    // existing selection when we just seeded it — never over unsaved edits.
    let preferred = files.first { $0.url == starterURL } ?? files.first
    if let preferred, selectedFile == nil || !files.contains(where: { $0 == selectedFile }) {
      select(preferred)
    } else if didSeed, let selectedFile, selectedFile.url == starterURL {
      select(selectedFile)
    }
  }

  private func refreshFiles(_ workspacePath: String) {
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
  }

  private func select(_ file: WorkspaceFile) {
    do {
      fileContent = try String(contentsOf: file.url, encoding: .utf8)
      selectedFile = file
      loadError = nil
    } catch {
      loadError = "Could not read \(file.fileName)"
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
      loadError = nil
    } catch {
      loadError = "Could not save \(file.fileName)"
    }
  }

  // MARK: - Starter file seeding

  private var languageProfile: (fileName: String, comment: String) {
    switch question?.languageHint?.lowercased() {
    case "python": return ("solution.py", "#")
    case "ruby": return ("solution.rb", "#")
    case "typescript": return ("solution.ts", "//")
    case "javascript": return ("solution.js", "//")
    case "kotlin": return ("Solution.kt", "//")
    case "java": return ("Solution.java", "//")
    case "c++", "cpp": return ("solution.cpp", "//")
    case "c": return ("solution.c", "//")
    case "go": return ("solution.go", "//")
    case "rust": return ("solution.rs", "//")
    default: return ("solution.swift", "//")
    }
  }

  private var starterFileName: String { languageProfile.fileName }

  /// The problem statement as a comment header, so reading and solving happen
  /// in the same buffer.
  private func seededContent(for question: Question) -> String {
    let comment = languageProfile.comment
    var lines: [String] = []

    var heading = "\(question.title) — \(question.difficulty.displayName)"
    if !question.topicIds.isEmpty {
      heading += " (\(question.topicIds.joined(separator: ", ")))"
    }
    lines.append("\(comment) \(heading)")
    lines.append(comment)

    for paragraph in question.promptMarkdown.components(separatedBy: "\n") {
      for wrapped in wrap(paragraph, width: 88) {
        lines.append(wrapped.isEmpty ? comment : "\(comment) \(wrapped)")
      }
    }

    lines.append(comment)
    lines.append("\(comment) Write your solution below. ⌘S saves — graded on End & Grade.")
    lines.append("")
    lines.append("")

    return lines.joined(separator: "\n")
  }

  private func wrap(_ text: String, width: Int) -> [String] {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return [""] }

    var lines: [String] = []
    var current = ""
    for word in trimmed.split(separator: " ") {
      if current.isEmpty {
        current = String(word)
      } else if current.count + word.count + 1 <= width {
        current += " \(word)"
      } else {
        lines.append(current)
        current = String(word)
      }
    }
    if !current.isEmpty {
      lines.append(current)
    }
    return lines
  }
}
