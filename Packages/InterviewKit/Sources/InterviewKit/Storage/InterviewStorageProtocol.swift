//
//  InterviewStorageProtocol.swift
//  InterviewKit
//

import Foundation

public protocol InterviewStorageProtocol: Sendable {
  func saveQuestion(_ q: Question) async throws
  func questions(mode: SessionMode?, topicId: String?, difficulty: Difficulty?) async throws -> [Question]
  func question(id: String) async throws -> Question?
  func createAttempt(_ a: InterviewAttempt) async throws
  func updateAttempt(_ a: InterviewAttempt) async throws
  func linkChatSession(attemptId: String, chatSessionId: String) async throws
  func attempts(limit: Int?) async throws -> [InterviewAttempt]
  func attempt(id: String) async throws -> InterviewAttempt?
  func attempt(forChatSessionId: String) async throws -> InterviewAttempt?
  func deleteAttempt(id: String) async throws
  func saveEvaluation(_ e: RubricEvaluation, notes: [ImprovementNote]) async throws
  func evaluation(forAttemptId: String) async throws -> RubricEvaluation?
  func openImprovementNotes() async throws -> [ImprovementNote]
  func notes(forAttemptId: String) async throws -> [ImprovementNote]
  func setNoteResolved(id: String, resolved: Bool) async throws
  func allTopics() async throws -> [Topic]
  func topicSkillStats() async throws -> [TopicSkillStat]
}
