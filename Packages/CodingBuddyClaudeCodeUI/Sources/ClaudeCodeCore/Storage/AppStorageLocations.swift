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
}
