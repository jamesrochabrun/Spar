//
//  RuleLibraryProviding.swift
//  CodingBuddyChat
//

import Foundation

@MainActor
public protocol RuleLibraryProviding: AnyObject {
  var ruleSets: [RuleSet] { get }
  var errorMessage: String? { get }

  func load()
  /// Copies an external rules document into the managed folder.
  func importRules(from url: URL)
  func delete(_ ruleSet: RuleSet)
  func revealInFinder(_ ruleSet: RuleSet)
  /// Re-reads the named sets from disk, so edits made in an external editor
  /// are picked up when the next session starts.
  func resolve(ids: [String]) -> RuleContext
}
