import Foundation

public protocol KnowledgeStorageProtocol: Sendable {
  func saveStudySpace(_ studySpace: StudySpace) async throws
  func studySpaces() async throws -> [StudySpace]
  func studySpace(id: String) async throws -> StudySpace?
  func deleteStudySpace(id: String) async throws

  func saveStudyPlan(_ studyPlan: StudyPlan) async throws
  func studyPlans() async throws -> [StudyPlan]
  func studyPlan(studySpaceID: String) async throws -> StudyPlan?
  func setStudyPlanItemCompletion(
    planID: String,
    itemID: String,
    isCompleted: Bool,
    completedAt: Date?
  ) async throws
  func deleteStudyPlan(id: String) async throws

  func saveSource(_ source: KnowledgeSource) async throws
  func sources(studySpaceID: String) async throws -> [KnowledgeSource]
  func replaceChunks(for sourceID: String, with chunks: [KnowledgeChunk]) async throws
  func chunks(studySpaceID: String, limit: Int) async throws -> [KnowledgeChunk]
  func chunk(id: String) async throws -> KnowledgeChunk?
  func search(studySpaceID: String, query: String, limit: Int) async throws -> [KnowledgeSearchResult]

  func saveSessionBinding(_ binding: KnowledgeSessionBinding) async throws
  func sessionBinding(chatSessionID: String) async throws -> KnowledgeSessionBinding?
  func deleteSessionBinding(chatSessionID: String) async throws
}

public protocol RepositoryIndexing: Sendable {
  func indexRepository(
    at repositoryURL: URL,
    in studySpace: StudySpace
  ) async throws -> KnowledgeSource
}
