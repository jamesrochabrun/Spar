import Foundation
import KnowledgeKit
import Testing
@testable import CodingBuddyChat

@MainActor
struct KnowledgeLibraryServiceTests {
  @Test
  func repositoryBecomesReusableGroundedContext() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("KnowledgeLibraryServiceTests-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("SampleRepo", isDirectory: true)
    let support = root.appendingPathComponent("Support", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try """
      actor SessionRegistry {
        private var sessions: [String: String] = [:]
        func cache(_ value: String, for id: String) { sessions[id] = value }
      }
      """.write(
        to: repository.appendingPathComponent("SessionRegistry.swift"),
        atomically: true,
        encoding: .utf8
      )

    let storage = SQLiteKnowledgeStorage(applicationSupportDirectory: support)
    let library = KnowledgeLibraryService(storage: storage)
    let studySpace = await library.addRepository(at: repository)

    #expect(studySpace?.name == "SampleRepo")
    #expect(library.studySpaces.count == 1)
    #expect(library.sources(studySpaceID: studySpace?.id ?? "").first?.indexStatus == .ready)

    let configuration = KnowledgeSessionConfiguration(
      studySpaceID: try #require(studySpace?.id),
      activity: .learn
    )
    let context = await library.makeContext(
      configuration: configuration,
      query: "How are sessions cached?"
    )

    #expect(context?.contains("SessionRegistry") == true)
    #expect(context?.contains("codingbuddy-source") == true)
    #expect(library.lastRetrieval.first?.chunk.relativePath == "SessionRegistry.swift")

    let plan = StudyPlan(
      id: "study-plan-\(try #require(studySpace?.id))",
      studySpaceID: try #require(studySpace?.id),
      title: "SampleRepo Plan",
      summary: "Trace repository behavior.",
      items: [
        StudyPlanItem(
          id: "session-registry",
          section: "Architecture",
          title: "Session Registry",
          objective: "Explain how the actor caches sessions.",
          sourcePaths: ["SessionRegistry.swift"]
        ),
      ]
    )
    #expect(await library.saveGeneratedStudyPlan(plan))
    let nextContext = await library.makeContext(
      configuration: configuration,
      query: BuddyAgentInstructions.nextStudyTopicMessage
    )
    #expect(nextContext?.contains("SessionRegistry") == true)
    #expect(nextContext?.contains("\"nextItemID\":\"session-registry\"") == true)

    let unsupportedContext = await library.makeContext(
      configuration: configuration,
      query: "quasar zoology"
    )
    #expect(unsupportedContext?.contains("no relevant passages") == true)
    #expect(library.lastRetrieval.isEmpty)
  }

  @Test
  func agentRetrievalNeverStompsPanelBrowseState() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("KnowledgeLibraryServiceTests-\(UUID().uuidString)", isDirectory: true)
    let repository = root.appendingPathComponent("SampleRepo", isDirectory: true)
    let support = root.appendingPathComponent("Support", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try "struct TimerModel { var remaining: Int }".write(
      to: repository.appendingPathComponent("TimerModel.swift"),
      atomically: true,
      encoding: .utf8
    )
    try "final class NetworkClient { func fetch() {} }".write(
      to: repository.appendingPathComponent("NetworkClient.swift"),
      atomically: true,
      encoding: .utf8
    )

    let storage = SQLiteKnowledgeStorage(applicationSupportDirectory: support)
    let library = KnowledgeLibraryService(storage: storage)
    let studySpace = try #require(await library.addRepository(at: repository))

    // The user searches in the Sources panel…
    await library.search(studySpaceID: studySpace.id, query: "TimerModel")
    let panelResults = library.latestResults
    let panelSelection = library.selectedChunk?.id
    #expect(panelResults.first?.chunk.relativePath == "TimerModel.swift")

    // …then sends a chat message that triggers agent retrieval on another topic.
    let configuration = KnowledgeSessionConfiguration(studySpaceID: studySpace.id, activity: .learn)
    _ = await library.makeContext(configuration: configuration, query: "NetworkClient fetch")

    // Panel state is untouched; retrieval is captured separately.
    #expect(library.latestResults.map(\.id) == panelResults.map(\.id))
    #expect(library.selectedChunk?.id == panelSelection)
    #expect(library.lastRetrieval.first?.chunk.relativePath == "NetworkClient.swift")
  }

  @Test
  func regeneratedPlanPreservesManualCompletionAndFeedsAgentContext() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("KnowledgeLibraryServiceTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let storage = SQLiteKnowledgeStorage(applicationSupportDirectory: root)
    let space = StudySpace(name: "SampleRepo")
    try await storage.saveStudySpace(space)
    let library = KnowledgeLibraryService(storage: storage)
    await library.load()

    let initial = StudyPlan(
      id: "study-plan-\(space.id)",
      studySpaceID: space.id,
      title: "Learn SampleRepo",
      summary: "Start with architecture.",
      items: [
        StudyPlanItem(
          id: "architecture",
          section: "Foundations",
          title: "Architecture",
          objective: "Map the modules."
        ),
      ]
    )
    #expect(await library.saveGeneratedStudyPlan(initial))
    await library.setStudyPlanItemCompletion(
      planID: initial.id,
      itemID: "architecture",
      isCompleted: true
    )

    var regenerated = initial
    regenerated.summary = "Updated after re-indexing."
    regenerated.items.append(StudyPlanItem(
      id: "testing",
      section: "Quality",
      title: "Testing",
      objective: "Understand the test strategy."
    ))
    #expect(await library.saveGeneratedStudyPlan(regenerated))

    let stored = try #require(library.studyPlan(studySpaceID: space.id))
    #expect(stored.items.first?.isCompleted == true)
    #expect(stored.nextIncompleteItem?.id == "testing")

    let context = await library.makeContext(
      configuration: KnowledgeSessionConfiguration(
        studySpaceID: space.id,
        activity: .learn
      ),
      query: "What should I learn next?"
    )
    #expect(context?.contains("<buddy-study-plan-state>") == true)
    #expect(context?.contains("\"nextItemID\":\"testing\"") == true)
  }
}
