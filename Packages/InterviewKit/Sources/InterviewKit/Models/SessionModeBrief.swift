//
//  SessionModeBrief.swift
//  InterviewKit
//
//  What actually differs between the modes, in the user's words. The picker
//  used to show mode names and nothing else, which made several coding modes
//  look like labels for the same session. These are the axes that
//  really differ: how much you get, when you find out how you did, and what
//  the session is for.
//

import Foundation

public struct SessionModeBrief: Equatable, Sendable {
  /// How much work the session holds ("One problem", "As many as you can").
  public let format: String
  /// The feedback regime — the axis that separates mock from drill.
  public let feedback: String
  /// The reason to pick this mode over its neighbours.
  public let bestFor: String

  public init(format: String, feedback: String, bestFor: String) {
    self.format = format
    self.feedback = feedback
    self.bestFor = bestFor
  }
}

extension SessionMode {
  public var brief: SessionModeBrief {
    switch self {
    case .mockInterview:
      return SessionModeBrief(
        format: "One problem, on the clock",
        feedback: "Held back until the end — the interviewer never says if you're right",
        bestFor: "Rehearsing the real thing: clarify, plan out loud, defend your complexity"
      )
    case .codingProject:
      return SessionModeBrief(
        format: "One 60-minute feature in a provided Xcode project",
        feedback: "A final code review of your Git diff, tests, and implementation choices",
        bestFor: "Reading unfamiliar SwiftUI code and shipping a practical change under time pressure"
      )
    case .drill:
      return SessionModeBrief(
        format: "Back-to-back short problems",
        feedback: "Instant verdict after every rep, difficulty adapts as you go",
        bestFor: "Volume: recognising the pattern fast, and finding the topics you fumble"
      )
    case .practice:
      return SessionModeBrief(
        format: "Untimed, you set the agenda",
        feedback: "Continuous — ask anything, see worked solutions",
        bestFor: "Learning something new, or studying a repository you've indexed"
      )
    case .systemDesign:
      return SessionModeBrief(
        format: "One design prompt and a shared whiteboard",
        feedback: "Pushback on trade-offs as you design",
        bestFor: "Requirements, estimation, and defending architecture decisions"
      )
    case .behavioral:
      return SessionModeBrief(
        format: "One STAR question at a time",
        feedback: "Probing follow-ups, then structured notes on each answer",
        bestFor: "Tightening stories about scope, your role, and measurable impact"
      )
    }
  }
}
