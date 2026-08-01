//
//  InterviewWorkspaceManager.swift
//  InterviewKit
//

import Foundation

public protocol InterviewWorkspaceManaging: Sendable {
  /// Creates (or reuses) the attempt workspace directory and returns its path.
  func createWorkspace(slug: String) throws -> String
}

/// Creates attempt workspaces under ~/Documents/CodingBuddy/Workspaces/<date>-<slug>.
/// User-visible and app-independent, mirroring Easel's LocalEaselProjectManager
/// placement policy.
public struct InterviewWorkspaceManager: InterviewWorkspaceManaging {

  private let rootDirectory: URL

  public init(rootDirectory: URL? = nil) {
    if let rootDirectory {
      self.rootDirectory = rootDirectory
    } else {
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
      self.rootDirectory = documents
        .appendingPathComponent("CodingBuddy", isDirectory: true)
        .appendingPathComponent("Workspaces", isDirectory: true)
    }
  }

  public func createWorkspace(slug: String) throws -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let datePrefix = formatter.string(from: Date())

    let sanitizedSlug = Self.sanitized(slug)
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
