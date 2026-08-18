//
//  AppStorageLocations.swift
//  ClaudeCodeUI
//

import Foundation

/// Shared on-disk locations for app-owned stores.
public enum AppStorageLocations {
  /// The app's Application Support directory
  /// (`~/Library/Application Support/CodingBuddy`), home to the SQLite
  /// databases and other app-owned persistence.
  public static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
    fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("CodingBuddy", isDirectory: true)
  }

  /// The app's user-visible Documents directory
  /// (`~/Documents/CodingBuddy`), home to attempt workspaces, Xcode interview
  /// projects, and house-rule documents.
  public static func documentsDirectory(fileManager: FileManager = .default) -> URL {
    let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    return documents.appendingPathComponent("CodingBuddy", isDirectory: true)
  }

  /// Where house-rule documents live. Deliberately user-visible: a rules file
  /// can be dropped in, edited, or removed with any editor.
  public static func rulesDirectory(fileManager: FileManager = .default) -> URL {
    documentsDirectory(fileManager: fileManager)
      .appendingPathComponent("Rules", isDirectory: true)
  }

  public static let rulesDisplayPath = "~/Documents/CodingBuddy/Rules"
}
