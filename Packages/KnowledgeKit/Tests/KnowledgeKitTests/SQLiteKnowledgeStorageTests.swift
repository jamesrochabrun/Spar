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
  func searchPrefersAllTermMatchesAndFallsBackToAnyTerm() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let space = StudySpace(name: "Repo")
    let source = KnowledgeSource(
      studySpaceID: space.id,
      displayName: "Repo",
      rootPath: "/tmp/Repo",
      indexStatus: .ready,
      indexedFileCount: 2,
      chunkCount: 2
    )
    let timerChunk = KnowledgeChunk(
      id: "timer",
      studySpaceID: space.id,
      sourceID: source.id,
      relativePath: "Timer.swift",
      startLine: 1,
      endLine: 5,
      content: "SessionTimer counts down the interview deadline.",
      contentHash: "a"
    )
    let networkChunk = KnowledgeChunk(
      id: "network",
      studySpaceID: space.id,
      sourceID: source.id,
      relativePath: "Network.swift",
      startLine: 1,
      endLine: 5,
      content: "NetworkClient fetches interview questions remotely.",
      contentHash: "b"
    )

    try await storage.saveStudySpace(space)
    try await storage.saveSource(source)
    try await storage.replaceChunks(for: source.id, with: [timerChunk, networkChunk])

    // Both terms appear only in the timer chunk: AND semantics keep the
    // network chunk (which matches just "interview") out.
    let allTerms = try await storage.search(
      studySpaceID: space.id,
      query: "timer interview",
      limit: 5
    )
    #expect(allTerms.map(\.chunk.id) == [timerChunk.id])

    // No chunk has every term, so the search falls back to any-term matches
    // instead of returning nothing.
    let fallback = try await storage.search(
      studySpaceID: space.id,
      query: "quasar interview",
      limit: 5
    )
    #expect(Set(fallback.map(\.chunk.id)) == [timerChunk.id, networkChunk.id])

    // Symbol-only queries are stripped to nothing and return empty safely.
    let symbols = try await storage.search(studySpaceID: space.id, query: "()->{}", limit: 5)
    #expect(symbols.isEmpty)

    // Single characters still prefix-match instead of dead-ending.
    let singleCharacter = try await storage.search(studySpaceID: space.id, query: "n", limit: 5)
    #expect(singleCharacter.contains { $0.chunk.id == networkChunk.id })
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

  @Test
  func studyPlanCompletionRoundTripsAndCascadesWithSpace() async throws {
    let (storage, root) = makeStorage()
    defer { try? FileManager.default.removeItem(at: root) }

    let space = StudySpace(name: "Repository")
    let plan = StudyPlan(
      id: "plan-\(space.id)",
      studySpaceID: space.id,
      title: "Repository Plan",
      summary: "Learn in order.",
      items: [
        StudyPlanItem(
          id: "architecture",
          section: "Foundations",
          title: "Architecture",
          objective: "Map the modules."
        ),
        StudyPlanItem(
          id: "testing",
          section: "Quality",
          title: "Testing",
          objective: "Understand the test strategy.",
          prerequisiteIDs: ["architecture"]
        ),
      ]
    )

    try await storage.saveStudySpace(space)
    try await storage.saveStudyPlan(plan)
    #expect(try await storage.studyPlan(studySpaceID: space.id) == plan)

    try await storage.setStudyPlanItemCompletion(
      planID: plan.id,
      itemID: "architecture",
      isCompleted: true,
      completedAt: .now
    )
    let completed = try #require(await storage.studyPlan(studySpaceID: space.id))
    #expect(completed.completedItemCount == 1)
    #expect(completed.items.first?.isCompleted == true)
    #expect(completed.nextIncompleteItem?.id == "testing")

    try await storage.deleteStudySpace(id: space.id)
    #expect(try await storage.studyPlan(studySpaceID: space.id) == nil)
  }
}
