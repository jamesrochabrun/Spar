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

  @ObservationIgnored private let defaults: UserDefaults

  static let specializationKey = "buddy.interview.specialization"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let stored = defaults.string(forKey: Self.specializationKey)
    self.specialization = stored.flatMap(InterviewSpecialization.init(rawValue:)) ?? .default
  }
}
