import Foundation
import Testing
@testable import KnowledgeKit

struct RepositoryKnowledgeIndexerTests {
  @Test
  func indexerSkipsSecretsAndMakesRepositorySearchable() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("KnowledgeKitIndexerTests-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("ExampleRepo", isDirectory: true)
    let support = root.appendingPathComponent("Support", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try "actor SessionCache { var values: [String: String] = [:] }"
      .write(to: repository.appendingPathComponent("SessionCache.swift"), atomically: true, encoding: .utf8)
    try "API_KEY=do-not-index"
      .write(to: repository.appendingPathComponent(".env"), atomically: true, encoding: .utf8)

    let storage = SQLiteKnowledgeStorage(applicationSupportDirectory: support)
    let space = StudySpace(name: "Example")
    try await storage.saveStudySpace(space)
    let indexer = RepositoryKnowledgeIndexer(storage: storage)
    let source = try await indexer.indexRepository(at: repository, in: space)

    #expect(source.indexStatus == .ready)
    #expect(source.indexedFileCount == 1)
    let cacheResults = try await storage.search(
      studySpaceID: space.id,
      query: "SessionCache values",
      limit: 5
    )
    let secretResults = try await storage.search(
      studySpaceID: space.id,
      query: "do-not-index",
      limit: 5
    )
    #expect(cacheResults.count == 1)
    #expect(cacheResults.first?.chunk.relativePath == "SessionCache.swift")
    #expect(secretResults.isEmpty)
  }
}
