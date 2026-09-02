//
//  SessionFocusBindingStore.swift
//  CodingBuddyChat
//
//  The session focus a chat session was started with, so resuming a session
//  restores the same coverage direction. Mirrors SessionRuleBindingStore: its
//  own JSON file, keyed by chat session id, separate from every SQLite schema.
//

import ClaudeCodeCore
import Foundation

public protocol SessionFocusBindingStoring: Sendable {
  func focus(chatSessionID: String) -> String?
  func save(focus: String?, chatSessionID: String)
  func delete(chatSessionID: String)
}

public struct FileSessionFocusBindingStore: SessionFocusBindingStoring {

  private let fileURL: URL

  public init(fileURL: URL? = nil) {
    self.fileURL = fileURL ?? AppStorageLocations.applicationSupportDirectory()
      .appendingPathComponent("SessionFocusBindings.json")
  }

  public func focus(chatSessionID: String) -> String? {
    load()[chatSessionID]
  }

  public func save(focus: String?, chatSessionID: String) {
    var bindings = load()
    if let focus, !focus.isEmpty {
      bindings[chatSessionID] = focus
    } else {
      bindings.removeValue(forKey: chatSessionID)
    }
    write(bindings)
  }

  public func delete(chatSessionID: String) {
    var bindings = load()
    guard bindings.removeValue(forKey: chatSessionID) != nil else { return }
    write(bindings)
  }

  private func load() -> [String: String] {
    guard let data = try? Data(contentsOf: fileURL),
          let bindings = try? JSONDecoder().decode([String: String].self, from: data)
    else { return [:] }
    return bindings
  }

  private func write(_ bindings: [String: String]) {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(bindings)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      // Best-effort: a failed save only means the next resume starts without
      // the focus attached, which the user can restate in chat.
    }
  }
}
