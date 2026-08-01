//
//  QuestionBankService.swift
//  InterviewKit
//

import Foundation
import Observation

/// Persists questions captured from buddy-question fences and serves
/// retry-from-bank browsing.
@Observable @MainActor
public final class QuestionBankService {

  public private(set) var lastSavedQuestion: Question?

  private let storage: any InterviewStorageProtocol

  public init(storage: any InterviewStorageProtocol) {
    self.storage = storage
  }

  @discardableResult
  public func save(_ question: Question) async -> Question {
    try? await storage.saveQuestion(question)
    lastSavedQuestion = question
    return question
  }

  public func questions(
    mode: SessionMode? = nil,
    topicId: String? = nil,
    difficulty: Difficulty? = nil
  ) async -> [Question] {
    (try? await storage.questions(mode: mode, topicId: topicId, difficulty: difficulty)) ?? []
  }

  public func question(id: String) async -> Question? {
    try? await storage.question(id: id)
  }
}
