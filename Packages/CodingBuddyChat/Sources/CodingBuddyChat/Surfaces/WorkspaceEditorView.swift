//
//  WorkspaceEditorView.swift
//  CodingBuddyChat
//
//  Workspace surface: the editor IS the surface. A solution file is created
//  automatically in the attempt workspace and seeded with the problem
//  statement as a comment header, so you read and solve in one place. A file
//  menu appears only when the workspace grows past one file (e.g. Spar wrote
//  test files).
//

import CodingBuddyKit
import InterviewKit
import SwiftUI

public struct WorkspaceEditorView: View {
  private let workspacePath: String?
  private let question: Question?
  private let externalRefreshToken: Int
  private let codeRunner: any CodeRunning
  private let fileMonitor: any WorkspaceFileMonitoring
  private let floatingAccessory: AnyView?

  @State private var files: [WorkspaceFile] = []
  @State private var selectedFile: WorkspaceFile?
  @State private var fileContent: String = ""
  @State private var editorContent: String = ""
  @State private var externalConflict: ExternalFileConflict?
  @State private var isSaving = false
  @State private var loadError: String?
  @State private var isRunning = false
  @State private var runResult: CodeRunResult?
  @State private var runErrorMessage: String?
  @State private var isConsoleVisible = false
  @State private var runTask: Task<Void, Never>?
  @State private var runGeneration = 0
  @Environment(\.colorScheme) private var colorScheme

  /// Called after the buffer is saved when the user asks for a coaching
  /// review; the file name is passed so the request can point at it.
  private let onReviewRequested: ((String) -> Void)?

  public init(
    workspacePath: String?,
    question: Question?,
    externalRefreshToken: Int = 0,
    codeRunner: any CodeRunning = ProcessCodeRunner(),
    fileMonitor: any WorkspaceFileMonitoring = PollingWorkspaceFileMonitor(),
    onReviewRequested: ((String) -> Void)? = nil,
    floatingAccessory: AnyView? = nil
  ) {
    self.workspacePath = workspacePath
    self.question = question
    self.externalRefreshToken = externalRefreshToken
    self.codeRunner = codeRunner
    self.fileMonitor = fileMonitor
    self.onReviewRequested = onReviewRequested
    self.floatingAccessory = floatingAccessory
  }

  struct WorkspaceFile: Identifiable, Equatable {
    let url: URL
    let relativePath: String
    var id: String { relativePath }
    var fileName: String { url.lastPathComponent }
  }

  struct ExternalFileConflict: Equatable {
    let fileID: String
  }

  public var body: some View {
    Group {
      if let workspacePath {
        VStack(spacing: 0) {
          workspaceBar

          Rectangle()
            .fill(EaselDesignSystem.Palette.border(for: colorScheme))
            .frame(height: 1)

          if externalConflict?.fileID == selectedFile?.id {
            externalConflictBar

            Rectangle()
              .fill(EaselDesignSystem.Palette.border(for: colorScheme))
              .frame(height: 1)
          }

          editorPane
        }
        .task(id: workspacePath) {
          prepareWorkspace(workspacePath)
          let workspaceURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
          for await _ in fileMonitor.changes(in: workspaceURL) {
            guard !Task.isCancelled else { break }
            prepareWorkspace(workspacePath)
          }
        }
        .onChange(of: question?.id) { _, _ in
          // The question often lands after the session starts: seed the still
          // untouched solution file with the problem header when it arrives.
          prepareWorkspace(workspacePath)
        }
        .onChange(of: externalRefreshToken) { _, _ in
          // Provider tools write directly to disk. Refresh completed turns so
          // new files appear and clean editor buffers adopt in-place edits.
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
        let runHint = selectedFile.map(canRun) == true ? "⌘R runs · " : ""
        Text("⌘S saves · \(runHint)graded on End & Grade")
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

  private var externalConflictBar: some View {
    HStack(spacing: 10) {
      Label(
        "This file changed on disk while you had unsaved edits.",
        systemImage: "exclamationmark.triangle.fill"
      )
        .font(.caption)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      Spacer(minLength: 8)

      Button("Reload Agent Version") {
        guard let selectedFile else { return }
        select(selectedFile)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)

      Button("Keep My Version") {
        guard let selectedFile else { return }
        save(editorContent, to: selectedFile, overwritingExternalChanges: true)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
    .padding(.horizontal, 14)
    .frame(minHeight: 38)
    .background(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.08))
  }

  @ViewBuilder
  private var editorPane: some View {
    if let selectedFile {
      VStack(spacing: 0) {
        ProjectResourceTextPreview(
          fileName: selectedFile.fileName,
          text: fileContent,
          isSaving: isSaving,
          onSave: { newText in
            save(newText, to: selectedFile)
          },
          isRunning: isRunning,
          onEditorTextChange: { editorContent = $0 },
          onRun: canRun(selectedFile) ? { latestText in
            saveAndRun(latestText, file: selectedFile)
          } : nil,
          onReview: onReviewRequested.map { onReviewRequested in
            { latestText in
              // Save first so the agent reads exactly what's on screen.
              guard save(latestText, to: selectedFile) else { return }
              onReviewRequested(selectedFile.fileName)
            }
          }
        )
        .id(selectedFile.id)
        .overlay(alignment: .bottomTrailing) {
          if let floatingAccessory {
            floatingAccessory
              .padding(18)
          }
        }

        if isConsoleVisible {
          Rectangle()
            .fill(EaselDesignSystem.Palette.border(for: colorScheme))
            .frame(height: 1)

          WorkspaceConsoleView(
            isRunning: isRunning,
            result: runResult,
            errorMessage: runErrorMessage,
            onStop: { runTask?.cancel() },
            onClose: {
              runTask?.cancel()
              isConsoleVisible = false
            }
          )
          .frame(height: 180)
        }
      }
    } else {
      ContentUnavailableView {
        Label("Preparing workspace…", systemImage: "doc.text")
      } description: {
        Text(loadError ?? "Your solution file opens here automatically.")
      }
    }
  }

  // MARK: - Run

  private func canRun(_ file: WorkspaceFile) -> Bool {
    codeRunner.language(forFileExtension: file.url.pathExtension) != nil
  }

  /// Saves the buffer, then compiles and runs the file, streaming the outcome
  /// into the console pane.
  private func saveAndRun(_ latestText: String, file: WorkspaceFile) {
    guard save(latestText, to: file) else { return }

    runTask?.cancel()
    isConsoleVisible = true
    isRunning = true
    runResult = nil
    runErrorMessage = nil
    runGeneration += 1
    let generation = runGeneration

    runTask = Task {
      var result: CodeRunResult?
      var message: String?
      do {
        result = try await codeRunner.run(fileURL: file.url)
      } catch is CancellationError {
        message = WorkspaceConsoleView.stoppedMessage
      } catch {
        message = error.localizedDescription
      }
      // A newer run may have superseded this one while it was in flight.
      guard generation == runGeneration else { return }
      runResult = result
      runErrorMessage = message
      isRunning = false
    }
  }

  // MARK: - Workspace preparation

  /// Ensures a solution file exists, seeded with raw starter source when the
  /// question provides it, then opens it.
  private func prepareWorkspace(_ workspacePath: String) {
    refreshFiles(workspacePath)

    let rootURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
    let starterURL = rootURL.appendingPathComponent(starterFileName)
    var didSeed = false

    if files.isEmpty {
      let seed = question.map(WorkspaceStarterContent.make(for:)) ?? ""
      try? seed.write(to: starterURL, atomically: true, encoding: .utf8)
      refreshFiles(workspacePath)
      didSeed = true
    } else if let question,
              let starter = files.first(where: { $0.url == starterURL }),
              let existing = try? String(contentsOf: starter.url, encoding: .utf8),
              existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              editorContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              editorContent == fileContent {
      // Question arrived after the file was created and it's still untouched
      // on disk AND in the visible buffer: seed it now. Never overwrite
      // anything the candidate typed.
      try? WorkspaceStarterContent.make(for: question).write(
        to: starter.url,
        atomically: true,
        encoding: .utf8
      )
      didSeed = true
    }

    // Prefer the solution file; fall back to the first file. If Spar wrote to
    // the already-open file, adopt that disk content only while the candidate
    // has no unsaved edits in the visible editor.
    let preferred = files.first { $0.url == starterURL }
      ?? files.first
    if let preferred, selectedFile == nil || !files.contains(where: { $0 == selectedFile }) {
      select(preferred)
    } else if let selectedFile,
              let refreshedSelection = files.first(where: { $0.id == selectedFile.id }) {
      reconcileWithDisk(refreshedSelection, forceReload: didSeed && selectedFile.url == starterURL)
    }
  }

  private func reconcileWithDisk(_ file: WorkspaceFile, forceReload: Bool) {
    guard let diskContent = try? String(contentsOf: file.url, encoding: .utf8) else { return }

    if forceReload {
      select(file)
      return
    }

    switch WorkspaceFileContentSync.resolution(
      diskContent: diskContent,
      baselineContent: fileContent,
      editorContent: editorContent
    ) {
    case .unchanged:
      if externalConflict?.fileID == file.id {
        externalConflict = nil
      }
    case .reloadFromDisk:
      select(file)
    case .acknowledgeEditor:
      fileContent = diskContent
      editorContent = diskContent
      externalConflict = nil
      loadError = nil
    case .conflict:
      externalConflict = ExternalFileConflict(fileID: file.id)
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
      editorContent = fileContent
      selectedFile = file
      externalConflict = nil
      loadError = nil
    } catch {
      loadError = "Could not read \(file.fileName)"
      selectedFile = nil
      fileContent = ""
      editorContent = ""
      externalConflict = nil
    }
  }

  @discardableResult
  private func save(
    _ text: String,
    to file: WorkspaceFile,
    overwritingExternalChanges: Bool = false
  ) -> Bool {
    editorContent = text

    if !overwritingExternalChanges,
       let diskContent = try? String(contentsOf: file.url, encoding: .utf8) {
      switch WorkspaceFileContentSync.resolution(
        diskContent: diskContent,
        baselineContent: fileContent,
        editorContent: text
      ) {
      case .unchanged:
        break
      case .reloadFromDisk:
        // A clean but stale editor must adopt the provider's newer file. This
        // is especially important for Run, which used to overwrite disk first.
        select(file)
        return true
      case .acknowledgeEditor:
        fileContent = diskContent
        editorContent = diskContent
        externalConflict = nil
        loadError = nil
        return true
      case .conflict:
        externalConflict = ExternalFileConflict(fileID: file.id)
        loadError = nil
        return false
      }
    }

    isSaving = true
    defer { isSaving = false }
    do {
      try text.write(to: file.url, atomically: true, encoding: .utf8)
      fileContent = text
      editorContent = text
      externalConflict = nil
      loadError = nil
      return true
    } catch {
      loadError = "Could not save \(file.fileName)"
      return false
    }
  }

  // MARK: - Starter file seeding

  private var starterFileName: String {
    WorkspaceStarterContent.fileName(for: question?.languageHint)
  }

}
