//
//  SessionRuleBindingStore.swift
//  CodingBuddyChat
//
//  Which rule sets a chat session was started with, so resuming a session
//  restores the same rules. Kept as its own JSON file rather than a table in
//  knowledge_library.sqlite — rules are not knowledge, and the two schemas
//  stay separate.
//

import ClaudeCodeCore
import Foundation

public protocol SessionRuleBindingStoring: Sendable {
  func ruleSetIDs(chatSessionID: String) -> [String]
  func save(ruleSetIDs: [String], chatSessionID: String)
  func delete(chatSessionID: String)
}

public struct FileSessionRuleBindingStore: SessionRuleBindingStoring {

  private let fileURL: URL

  public init(fileURL: URL? = nil) {
    self.fileURL = fileURL ?? AppStorageLocations.applicationSupportDirectory()
      .appendingPathComponent("SessionRuleBindings.json")
  }

  public func ruleSetIDs(chatSessionID: String) -> [String] {
    load()[chatSessionID] ?? []
  }

  public func save(ruleSetIDs: [String], chatSessionID: String) {
    var bindings = load()
    if ruleSetIDs.isEmpty {
      bindings.removeValue(forKey: chatSessionID)
    } else {
      bindings[chatSessionID] = ruleSetIDs
    }
    write(bindings)
  }

  public func delete(chatSessionID: String) {
    var bindings = load()
    guard bindings.removeValue(forKey: chatSessionID) != nil else { return }
    write(bindings)
  }

  private func load() -> [String: [String]] {
    guard let data = try? Data(contentsOf: fileURL),
          let bindings = try? JSONDecoder().decode([String: [String]].self, from: data)
    else { return [:] }
    return bindings
  }

  private func write(_ bindings: [String: [String]]) {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(bindings)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      // Best-effort: a failed save only means the next resume starts without
      // the rules attached, which the user can re-pick.
    }
  }
}
