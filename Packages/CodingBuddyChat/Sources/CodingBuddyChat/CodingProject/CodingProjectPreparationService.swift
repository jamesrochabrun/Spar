import CodingBuddyKit
import Foundation

public struct CodingProjectPreparationService: CodingProjectPreparing {
  private static let excludedNames: Set<String> = [
    ".git",
    ".build",
    ".DS_Store",
    ".swiftpm",
    "DerivedData",
    "xcuserdata",
  ]

  private static let gitIgnoreEntries = [
    ".DS_Store",
    ".build/",
    ".swiftpm/",
    "DerivedData/",
    "xcuserdata/",
  ]

  private let commandRunner: any CodingProjectCommandRunning

  public init() {
    self.commandRunner = GitCommandRunner()
  }

  init(commandRunner: any CodingProjectCommandRunning) {
    self.commandRunner = commandRunner
  }

  public func prepareImportedProject(from sourceURL: URL, in workspaceURL: URL) async throws {
    let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if didStartAccess {
        sourceURL.stopAccessingSecurityScopedResource()
      }
    }

    let sourceValues = try sourceURL.resourceValues(forKeys: [.isDirectoryKey])
    guard sourceValues.isDirectory == true else {
      throw CodingProjectPreparationError.sourceIsNotDirectory
    }
    guard CodingProjectLocator.projectURL(in: sourceURL) != nil else {
      throw CodingProjectPreparationError.xcodeProjectNotFound
    }

    try ensureEmptyWorkspace(workspaceURL)
    try copyContents(from: sourceURL, to: workspaceURL)
    try ensureGitIgnore(in: workspaceURL)
    try await createGitBaseline(in: workspaceURL)
  }

  private func ensureEmptyWorkspace(_ workspaceURL: URL) throws {
    try FileManager.default.createDirectory(
      at: workspaceURL,
      withIntermediateDirectories: true
    )
    let contents = try FileManager.default.contentsOfDirectory(
      at: workspaceURL,
      includingPropertiesForKeys: nil
    )
    guard contents.isEmpty else {
      throw CodingProjectPreparationError.workspaceIsNotEmpty
    }
  }

  private func copyContents(from sourceURL: URL, to workspaceURL: URL) throws {
    let contents = try FileManager.default.contentsOfDirectory(
      at: sourceURL,
      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
    )
    for sourceItem in contents where !Self.excludedNames.contains(sourceItem.lastPathComponent) {
      let destinationItem = workspaceURL.appending(path: sourceItem.lastPathComponent)
      try copyRecursively(from: sourceItem, to: destinationItem)
    }
  }

  private func copyRecursively(from sourceURL: URL, to destinationURL: URL) throws {
    let values = try sourceURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    if values.isSymbolicLink == true || values.isDirectory != true {
      try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
      return
    }

    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
    let children = try FileManager.default.contentsOfDirectory(
      at: sourceURL,
      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
    )
    for child in children where !Self.excludedNames.contains(child.lastPathComponent) {
      try copyRecursively(
        from: child,
        to: destinationURL.appending(path: child.lastPathComponent)
      )
    }
  }

  private func ensureGitIgnore(in workspaceURL: URL) throws {
    let gitIgnoreURL = workspaceURL.appending(path: ".gitignore")
    let existing = (try? String(contentsOf: gitIgnoreURL, encoding: .utf8)) ?? ""
    var lines = existing.components(separatedBy: .newlines)
    for entry in Self.gitIgnoreEntries where !lines.contains(entry) {
      lines.append(entry)
    }
    let normalized = lines
      .drop(while: { $0.isEmpty })
      .joined(separator: "\n")
      .trimmingCharacters(in: .newlines) + "\n"
    try normalized.write(to: gitIgnoreURL, atomically: true, encoding: .utf8)
  }

  private func createGitBaseline(in workspaceURL: URL) async throws {
    try await commandRunner.runGit(arguments: ["init"], in: workspaceURL)
    try await commandRunner.runGit(arguments: ["add", "--all"], in: workspaceURL)
    try await commandRunner.runGit(
      arguments: [
        "-c", "user.name=\(AppBrand.name)",
        "-c", "user.email=interview@codingbuddy.local",
        "commit", "-m", "\(AppBrand.name) interview baseline",
      ],
      in: workspaceURL
    )
  }
}
