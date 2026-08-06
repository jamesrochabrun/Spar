import Foundation
import KnowledgeKit

@Observable @MainActor
public final class KnowledgeLibraryService {
  public private(set) var studySpaces: [StudySpace] = []
  public private(set) var sourcesByStudySpaceID: [String: [KnowledgeSource]] = [:]
  public private(set) var latestResults: [KnowledgeSearchResult] = []
  public private(set) var selectedChunk: KnowledgeChunk?
  public var selectedChunkID: String? { selectedChunk?.id }
  public private(set) var isImporting = false
  public private(set) var errorMessage: String?

  @ObservationIgnored private let storage: any KnowledgeStorageProtocol
  @ObservationIgnored private let repositoryIndexer: any RepositoryIndexing

  public init(
    storage: (any KnowledgeStorageProtocol)? = nil,
    repositoryIndexer: (any RepositoryIndexing)? = nil
  ) {
    let resolvedStorage = storage ?? SQLiteKnowledgeStorage()
    self.storage = resolvedStorage
    self.repositoryIndexer = repositoryIndexer ?? RepositoryKnowledgeIndexer(storage: resolvedStorage)
  }

  public func load() async {
    do {
      let spaces = try await storage.studySpaces()
      var sources: [String: [KnowledgeSource]] = [:]
      for space in spaces {
        sources[space.id] = try await storage.sources(studySpaceID: space.id)
      }
      studySpaces = spaces
      sourcesByStudySpaceID = sources
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  public func addRepository(at repositoryURL: URL) async -> StudySpace? {
    guard !isImporting else { return nil }
    isImporting = true
    errorMessage = nil
    defer { isImporting = false }

    let displayName = repositoryURL.lastPathComponent.isEmpty
      ? "Repository"
      : repositoryURL.lastPathComponent
    let studySpace = StudySpace(name: displayName)

    do {
      try await storage.saveStudySpace(studySpace)
      _ = try await repositoryIndexer.indexRepository(at: repositoryURL, in: studySpace)
      await load()
      return studySpace
    } catch {
      errorMessage = error.localizedDescription
      await load()
      return nil
    }
  }

  public func deleteStudySpace(_ studySpace: StudySpace) async {
    do {
      try await storage.deleteStudySpace(id: studySpace.id)
      if selectedChunk?.studySpaceID == studySpace.id {
        selectedChunk = nil
        latestResults = []
      }
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func studySpace(id: String?) -> StudySpace? {
    guard let id else { return nil }
    return studySpaces.first { $0.id == id }
  }

  public func sources(studySpaceID: String) -> [KnowledgeSource] {
    sourcesByStudySpaceID[studySpaceID] ?? []
  }

  public func browse(studySpaceID: String, limit: Int = 80) async {
    do {
      let chunks = try await storage.chunks(studySpaceID: studySpaceID, limit: limit)
      latestResults = chunks.map { KnowledgeSearchResult(chunk: $0, score: 0) }
      if selectedChunk?.studySpaceID != studySpaceID {
        selectedChunk = chunks.first
      }
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func search(studySpaceID: String, query: String, limit: Int = 20) async {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      await browse(studySpaceID: studySpaceID)
      return
    }

    do {
      latestResults = try await storage.search(
        studySpaceID: studySpaceID,
        query: trimmedQuery,
        limit: limit
      )
      selectedChunk = latestResults.first?.chunk
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func selectChunk(id: String) async {
    do {
      selectedChunk = try await storage.chunk(id: id)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func makeContext(
    configuration: KnowledgeSessionConfiguration,
    query: String
  ) async -> String? {
    var resolvedStudySpace = studySpace(id: configuration.studySpaceID)
    if resolvedStudySpace == nil {
      resolvedStudySpace = try? await storage.studySpace(id: configuration.studySpaceID)
    }
    guard let studySpace = resolvedStudySpace else {
      return nil
    }

    let retrievalQuery = Self.retrievalQuery(for: query, activity: configuration.activity)
    let results = (try? await storage.search(
      studySpaceID: configuration.studySpaceID,
      query: retrievalQuery,
      limit: 10
    )) ?? []
    let resolvedResults: [KnowledgeSearchResult]
    if results.isEmpty, Self.isGenericKickoff(query) {
      let fallback = (try? await storage.chunks(
        studySpaceID: configuration.studySpaceID,
        limit: 8
      )) ?? []
      resolvedResults = fallback.map { KnowledgeSearchResult(chunk: $0, score: 0) }
    } else {
      resolvedResults = results
    }

    latestResults = resolvedResults
    if selectedChunk?.studySpaceID != configuration.studySpaceID {
      selectedChunk = resolvedResults.first?.chunk
    }
    return KnowledgeContextBuilder.makeContext(
      studySpace: studySpace,
      results: resolvedResults,
      allowsVisibleCitations: configuration.sourceAccess == .openBook ||
        configuration.activity == .learn ||
        query.localizedCaseInsensitiveContains("[EVALUATE NOW]")
    )
  }

  public func saveSessionBinding(
    chatSessionID: String,
    configuration: KnowledgeSessionConfiguration
  ) async {
    try? await storage.saveSessionBinding(KnowledgeSessionBinding(
      chatSessionID: chatSessionID,
      configuration: configuration
    ))
  }

  public func sessionConfiguration(chatSessionID: String) async -> KnowledgeSessionConfiguration? {
    try? await storage.sessionBinding(chatSessionID: chatSessionID)?.configuration
  }

  public func deleteSessionBinding(chatSessionID: String) async {
    try? await storage.deleteSessionBinding(chatSessionID: chatSessionID)
  }

  private static func retrievalQuery(
    for query: String,
    activity: KnowledgeActivity
  ) -> String {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard isGenericKickoff(trimmed) else { return trimmed }

    switch activity {
    case .learn:
      return "README overview architecture entry point responsibilities data flow"
    case .interview:
      return "architecture design responsibilities tradeoffs public API tests README"
    }
  }

  private static func isGenericKickoff(_ query: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ||
      trimmed.localizedCaseInsensitiveContains("let's begin") ||
      trimmed.localizedCaseInsensitiveContains("present my first question")
  }
}
