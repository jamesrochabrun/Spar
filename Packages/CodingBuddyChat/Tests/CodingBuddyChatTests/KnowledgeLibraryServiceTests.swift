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
    #expect(library.latestResults.first?.chunk.relativePath == "SessionRegistry.swift")

    let unsupportedContext = await library.makeContext(
      configuration: configuration,
      query: "quasar zoology"
    )
    #expect(unsupportedContext?.contains("no relevant passages") == true)
    #expect(library.latestResults.isEmpty)
  }
}
