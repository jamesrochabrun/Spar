//
//  InterviewWorkspaceManager.swift
//  InterviewKit
//

import Foundation

public enum InterviewWorkspaceKind: Sendable {
  case scratch
  case xcodeProject
}

public protocol InterviewWorkspaceManaging: Sendable {
  /// Creates (or reuses) the attempt workspace directory and returns its path.
  func createWorkspace(slug: String, kind: InterviewWorkspaceKind) throws -> String
  /// Deletes a workspace previously created inside the managed root.
  func deleteWorkspace(atPath path: String) throws
}

/// Creates scratch workspaces under `~/Documents/CodingBuddy/Workspaces/` and
/// Xcode interview projects under `~/Documents/CodingBuddy/Xcode Projects/`.
/// User-visible and app-independent, mirroring Easel's LocalEaselProjectManager
/// placement policy.
public struct InterviewWorkspaceManager: InterviewWorkspaceManaging {
  public static let xcodeProjectsDisplayPath = "~/Documents/CodingBuddy/Xcode Projects"

  private let scratchRootDirectory: URL
  private let xcodeProjectsRootDirectory: URL

  public init(
    rootDirectory: URL? = nil,
    xcodeProjectsRootDirectory: URL? = nil
  ) {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    let appDocuments = documents.appendingPathComponent("CodingBuddy", isDirectory: true)
    let resolvedScratchRoot = rootDirectory
      ?? appDocuments.appendingPathComponent("Workspaces", isDirectory: true)

    self.scratchRootDirectory = resolvedScratchRoot
    self.xcodeProjectsRootDirectory = xcodeProjectsRootDirectory
      ?? (rootDirectory == nil
        ? appDocuments.appendingPathComponent("Xcode Projects", isDirectory: true)
        : resolvedScratchRoot.appendingPathComponent("Xcode Projects", isDirectory: true))
  }

  public func createWorkspace(slug: String, kind: InterviewWorkspaceKind) throws -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let datePrefix = formatter.string(from: Date())

    let sanitizedSlug = Self.sanitized(slug)
    let rootDirectory = rootDirectory(for: kind)
    var directory = rootDirectory.appendingPathComponent(
      "\(datePrefix)-\(sanitizedSlug)", isDirectory: true
    )

    // Avoid clobbering an existing attempt's workspace on name collision.
    var suffix = 2
    while FileManager.default.fileExists(atPath: directory.path) {
      directory = rootDirectory.appendingPathComponent(
        "\(datePrefix)-\(sanitizedSlug)-\(suffix)", isDirectory: true
      )
      suffix += 1
    }

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.path
  }

  public func deleteWorkspace(atPath path: String) throws {
    let workspace = URL(fileURLWithPath: path, isDirectory: true)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let managedRoots = [scratchRootDirectory, xcodeProjectsRootDirectory].map {
      $0.standardizedFileURL.resolvingSymlinksInPath()
    }

    guard managedRoots.contains(workspace.deletingLastPathComponent()),
          !managedRoots.contains(workspace) else {
      throw InterviewWorkspaceError.unmanagedPath(path)
    }

    guard FileManager.default.fileExists(atPath: workspace.path) else { return }
    try FileManager.default.removeItem(at: workspace)
  }

  private func rootDirectory(for kind: InterviewWorkspaceKind) -> URL {
    switch kind {
    case .scratch: return scratchRootDirectory
    case .xcodeProject: return xcodeProjectsRootDirectory
    }
  }

  static func sanitized(_ slug: String) -> String {
    let lowered = slug.lowercased()
    let mapped = lowered.map { character -> Character in
      if character.isLetter || character.isNumber { return character }
      return "-"
    }
    let collapsed = String(mapped)
      .split(separator: "-", omittingEmptySubsequences: true)
      .joined(separator: "-")
    let trimmed = String(collapsed.prefix(48))
    return trimmed.isEmpty ? "attempt" : trimmed
  }
}
