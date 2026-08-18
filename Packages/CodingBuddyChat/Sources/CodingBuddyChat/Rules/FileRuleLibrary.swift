//
//  FileRuleLibrary.swift
//  CodingBuddyChat
//
//  Rule sets live as plain files in the app's user-visible rules folder — the
//  same placement policy as attempt workspaces and Xcode interview projects.
//  The folder is the source of truth: drop a Markdown file in by hand and it
//  shows up, edit one in any editor and the next session picks up the change.
//

import AppKit
import ClaudeCodeCore
import Foundation
import Observation

@MainActor
@Observable
public final class FileRuleLibrary: RuleLibraryProviding {

  public static let displayPath = AppStorageLocations.rulesDisplayPath
  static let supportedExtensions: Set<String> = ["md", "markdown", "txt"]

  public private(set) var ruleSets: [RuleSet] = []
  public private(set) var errorMessage: String?

  public let rootDirectory: URL

  @ObservationIgnored private let fileManager: FileManager

  public init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
    self.rootDirectory = rootDirectory
      ?? AppStorageLocations.rulesDirectory(fileManager: fileManager)
    self.fileManager = fileManager
  }

  // MARK: - Library

  public func load() {
    do {
      try ensureRootExists()
      let contents = try fileManager.contentsOfDirectory(
        at: rootDirectory,
        includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )
      ruleSets = contents
        .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
        .compactMap(makeRuleSet(for:))
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      errorMessage = nil
    } catch {
      ruleSets = []
      errorMessage = "Could not read the rules folder: \(error.localizedDescription)"
    }
  }

  public func importRules(from url: URL) {
    let needsScope = url.startAccessingSecurityScopedResource()
    defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

    do {
      try ensureRootExists()
      let destination = availableDestination(forFileNamed: url.lastPathComponent)
      try fileManager.copyItem(at: url, to: destination)
      errorMessage = nil
    } catch {
      errorMessage = "Could not add those rules: \(error.localizedDescription)"
    }
    load()
  }

  public func delete(_ ruleSet: RuleSet) {
    do {
      try fileManager.removeItem(at: ruleSet.fileURL)
      errorMessage = nil
    } catch {
      errorMessage = "Could not delete \(ruleSet.name): \(error.localizedDescription)"
    }
    load()
  }

  public func revealInFinder(_ ruleSet: RuleSet) {
    NSWorkspace.shared.activateFileViewerSelecting([ruleSet.fileURL])
  }

  public func revealFolderInFinder() {
    try? ensureRootExists()
    NSWorkspace.shared.activateFileViewerSelecting([rootDirectory])
  }

  // MARK: - Resolution

  /// Bodies are read here rather than cached at `load()` so an edit made
  /// outside the app applies to the next session without a relaunch. Ids that
  /// no longer resolve — a deleted or renamed file — are skipped silently;
  /// the session still starts, just without that set.
  public func resolve(ids: [String]) -> RuleContext {
    guard !ids.isEmpty else { return .empty }
    let byID = Dictionary(uniqueKeysWithValues: ruleSets.map { ($0.id, $0) })
    let candidates: [(name: String, body: String)] = ids.compactMap { id in
      guard let ruleSet = byID[id],
            let body = try? String(contentsOf: ruleSet.fileURL, encoding: .utf8)
      else { return nil }
      return (name: ruleSet.name, body: body)
    }
    return RuleContext.make(from: candidates)
  }

  // MARK: - Helpers

  private func ensureRootExists() throws {
    try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
  }

  private func makeRuleSet(for url: URL) -> RuleSet? {
    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
    let name = url.deletingPathExtension().lastPathComponent
    guard !name.isEmpty else { return nil }
    return RuleSet(
      id: RuleSet.identifier(forFileNamed: name),
      name: name,
      fileURL: url,
      characterCount: values?.fileSize ?? 0,
      updatedAt: values?.contentModificationDate ?? .distantPast
    )
  }

  /// Never clobber an existing rules file on import — suffix instead, the same
  /// way `InterviewWorkspaceManager` resolves workspace name collisions.
  private func availableDestination(forFileNamed fileName: String) -> URL {
    var destination = rootDirectory.appendingPathComponent(fileName)
    guard fileManager.fileExists(atPath: destination.path) else { return destination }

    let base = (fileName as NSString).deletingPathExtension
    let pathExtension = (fileName as NSString).pathExtension
    var suffix = 2
    repeat {
      let candidate = pathExtension.isEmpty
        ? "\(base)-\(suffix)"
        : "\(base)-\(suffix).\(pathExtension)"
      destination = rootDirectory.appendingPathComponent(candidate)
      suffix += 1
    } while fileManager.fileExists(atPath: destination.path)

    return destination
  }
}
