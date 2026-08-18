//
//  BuddyInterviewSettings.swift
//  CodingBuddyChat
//
//  App-owned interview preferences (currently the specialization track).
//  Persists to UserDefaults; injectable suite for tests. ChatService reads
//  the specialization when it builds a session context, so a change here
//  applies to the next session started.
//

import Foundation
import InterviewKit
import Observation

@MainActor
@Observable
public final class BuddyInterviewSettings {

  public var specialization: InterviewSpecialization {
    didSet { defaults.set(specialization.rawValue, forKey: Self.specializationKey) }
  }

  /// House-rule sets pre-checked for every new session. The New Session sheet
  /// seeds its selection from this and lets the candidate uncheck per session,
  /// so a standing style guide does not have to be re-picked each time.
  public var defaultRuleSetIDs: [String] {
    didSet { defaults.set(defaultRuleSetIDs, forKey: Self.defaultRuleSetIDsKey) }
  }

  @ObservationIgnored private let defaults: UserDefaults

  static let specializationKey = "buddy.interview.specialization"
  static let defaultRuleSetIDsKey = "buddy.interview.defaultRuleSets"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let stored = defaults.string(forKey: Self.specializationKey)
    self.specialization = stored.flatMap(InterviewSpecialization.init(rawValue:)) ?? .default
    self.defaultRuleSetIDs = defaults.stringArray(forKey: Self.defaultRuleSetIDsKey) ?? []
  }
}
