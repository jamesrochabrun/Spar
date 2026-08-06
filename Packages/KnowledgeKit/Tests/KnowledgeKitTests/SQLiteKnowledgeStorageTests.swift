import Foundation
import Testing
@testable import KnowledgeKit

struct SQLiteKnowledgeStorageTests {
  private func makeStorage() -> (SQLiteKnowledgeStorage, URL) {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("KnowledgeKitStorageTests-\(UUID().uuidString)", isDirectory: true)
    return (SQLiteKnowledgeStorage(applicationSupportDirectory: root), root)
  }

  @Test
  func studySpaceSourceAndChunkRoundTrip() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let space = StudySpace(name: "CodingBuddy")
    let source = KnowledgeSource(
      studySpaceID: space.id,
      displayName: "CodingBuddy",
      rootPath: "/tmp/CodingBuddy",
      indexStatus: .ready,
      indexedFileCount: 1,
      chunkCount: 1
    )
    let chunk = KnowledgeChunk(
      id: "chunk-1",
      studySpaceID: space.id,
      sourceID: source.id,
      relativePath: "Sources/ChatService.swift",
      startLine: 10,
      endLine: 20,
      content: "The ChatService caches a context per session.",
      contentHash: "hash"
    )

    try await storage.saveStudySpace(space)
    try await storage.saveSource(source)
    try await storage.replaceChunks(for: source.id, with: [chunk])

    let storedSpaces = try await storage.studySpaces()
    #expect(storedSpaces.map(\.id) == [space.id])
    #expect(storedSpaces.map(\.name) == [space.name])
    #expect(try await storage.sources(studySpaceID: space.id) == [source])
    #expect(try await storage.chunk(id: chunk.id) == chunk)

    let results = try await storage.search(
      studySpaceID: space.id,
      query: "session context cache",
      limit: 5
    )
    #expect(results.map(\.chunk.id) == [chunk.id])
  }

  @Test
  func sessionBindingRoundTripsAndCascadesWithSpace() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let space = StudySpace(name: "Book")
    let binding = KnowledgeSessionBinding(
      chatSessionID: "chat-1",
      configuration: KnowledgeSessionConfiguration(
        studySpaceID: space.id,
        activity: .interview,
        sourceAccess: .closedBook
      )
    )

    try await storage.saveStudySpace(space)
    try await storage.saveSessionBinding(binding)
    let storedBinding = try await storage.sessionBinding(chatSessionID: "chat-1")
    #expect(storedBinding?.chatSessionID == binding.chatSessionID)
    #expect(storedBinding?.configuration == binding.configuration)

    try await storage.deleteStudySpace(id: space.id)
    #expect(try await storage.sessionBinding(chatSessionID: "chat-1") == nil)
  }
}
