//
//  SessionReportPresentation.swift
//  CodingBuddyChat
//

import InterviewKit

enum SessionReportPresentation: Equatable {
  case evaluation
  case grading
  case empty

  static func resolve(
    hasEvaluation: Bool,
    attemptStatus: InterviewAttempt.Status?,
    isGenerating: Bool = false
  ) -> SessionReportPresentation {
    if hasEvaluation {
      return .evaluation
    }
    if isGenerating || attemptStatus == .awaitingEvaluation {
      return .grading
    }
    return .empty
  }
}
