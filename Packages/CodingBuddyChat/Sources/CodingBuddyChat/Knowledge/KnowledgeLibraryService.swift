import Foundation
import KnowledgeKit

@Observable @MainActor
public final class KnowledgeLibraryService {
  public private(set) var studySpaces: [StudySpace] = []
  public private(set) var studyPlans: [StudyPlan] = []
  public private(set) var sourcesByStudySpaceID: [String: [KnowledgeSource]] = [:]
  public private(set) var latestResults: [KnowledgeSearchResult] = []
  public private(set) var selectedChunk: KnowledgeChunk?
  public var selectedChunkID: String? { selectedChunk?.id }
  public private(set) var isImporting = false
  public private(set) var errorMessage: String?
  /// Passages retrieved for the most recent outgoing message, kept separate
  /// from the panel's browse/search state so agent retrieval never stomps
  /// what the user is looking at.
  public private(set) var lastRetrieval: [KnowledgeSearchResult] = []
  public private(set) var lastRetrievalQuery: String?

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
      studyPlans = try await storage.studyPlans()
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
      if lastRetrieval.contains(where: { $0.chunk.studySpaceID == studySpace.id }) {
        lastRetrieval = []
        lastRetrievalQuery = nil
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

  public func studyPlan(studySpaceID: String?) -> StudyPlan? {
    guard let studySpaceID else { return nil }
    return studyPlans.first { $0.studySpaceID == studySpaceID }
  }

  @discardableResult
  public func saveGeneratedStudyPlan(_ studyPlan: StudyPlan) async -> Bool {
    do {
      var existing = self.studyPlan(studySpaceID: studyPlan.studySpaceID)
      if existing == nil {
        existing = try await storage.studyPlan(studySpaceID: studyPlan.studySpaceID)
      }
      let completionByItemID = Dictionary(
        uniqueKeysWithValues: (existing?.items ?? []).map {
          ($0.id, ($0.isCompleted, $0.completedAt))
        }
      )
      var mergedPlan = studyPlan
      mergedPlan.items = studyPlan.items.map { item in
        var mergedItem = item
        if let completion = completionByItemID[item.id] {
          mergedItem.isCompleted = completion.0
          mergedItem.completedAt = completion.1
        }
        return mergedItem
      }
      if let existing {
        mergedPlan = StudyPlan(
          id: existing.id,
          studySpaceID: mergedPlan.studySpaceID,
          title: mergedPlan.title,
          summary: mergedPlan.summary,
          items: mergedPlan.items,
          createdAt: existing.createdAt,
          updatedAt: .now
        )
      }
      try await storage.saveStudyPlan(mergedPlan)
      try await reloadStudyPlans()
      errorMessage = nil
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  public func setStudyPlanItemCompletion(
    planID: String,
    itemID: String,
    isCompleted: Bool
  ) async {
    do {
      try await storage.setStudyPlanItemCompletion(
        planID: planID,
        itemID: itemID,
        isCompleted: isCompleted,
        completedAt: isCompleted ? .now : nil
      )
      try await reloadStudyPlans()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func deleteStudyPlan(_ studyPlan: StudyPlan) async {
    do {
      try await storage.deleteStudyPlan(id: studyPlan.id)
      try await reloadStudyPlans()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func sources(studySpaceID: String) -> [KnowledgeSource] {
    sourcesByStudySpaceID[studySpaceID] ?? []
  }

  public func browse(studySpaceID: String, limit: Int = 80) async {
    do {
      let chunks = try await storage.chunks(studySpaceID: studySpaceID, limit: limit)
      latestResults = chunks.map { KnowledgeSearchResult(chunk: $0, score: 0) }
      reconcileSelection(studySpaceID: studySpaceID)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func search(studySpaceID: String, query: String, limit: Int = 40) async {
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
      // An explicit search with no hits clears the preview too — a stale
      // passage next to "No Results" reads as a wrong match.
      reconcileSelection(studySpaceID: studySpaceID, clearsWhenEmpty: true)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Keeps the preview stable while the result list refreshes: the current
  /// selection survives if it is still listed; otherwise fall back to the
  /// first result (or clear a selection left over from another space).
  private func reconcileSelection(studySpaceID: String, clearsWhenEmpty: Bool = false) {
    if latestResults.contains(where: { $0.chunk.id == selectedChunk?.id }) {
      return
    }
    if let first = latestResults.first?.chunk {
      selectedChunk = first
    } else if clearsWhenEmpty || selectedChunk?.studySpaceID != studySpaceID {
      selectedChunk = nil
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

  /// Monotonic signal for transcript citation clicks. Unlike plain chunk
  /// selection (which panel browsing also mutates), observing this lets the
  /// UI reveal the Sources surface only for explicit citation taps.
  public private(set) var citationActivationCount = 0

  public func openCitation(chunkID: String) async {
    await selectChunk(id: chunkID)
    citationActivationCount += 1
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

    var plan = studyPlan(studySpaceID: configuration.studySpaceID)
    if plan == nil, configuration.activity == .learn {
      plan = try? await storage.studyPlan(studySpaceID: configuration.studySpaceID)
    }
    let retrievalQuery = Self.retrievalQuery(
      for: query,
      activity: configuration.activity,
      plan: plan
    )
    let results: [KnowledgeSearchResult]
    if Self.isStudyPlanGeneration(query) {
      results = await studyPlanEvidence(
        studySpaceID: configuration.studySpaceID,
        query: retrievalQuery
      )
    } else {
      results = (try? await storage.search(
        studySpaceID: configuration.studySpaceID,
        query: retrievalQuery,
        limit: 10
      )) ?? []
    }
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

    lastRetrieval = resolvedResults
    lastRetrievalQuery = retrievalQuery
    let evidenceContext = KnowledgeContextBuilder.makeContext(
      studySpace: studySpace,
      results: resolvedResults,
      maximumCharacters: Self.isStudyPlanGeneration(query) ? 32_000 : 24_000,
      allowsVisibleCitations: configuration.sourceAccess == .openBook ||
        configuration.activity == .learn ||
        query.localizedCaseInsensitiveContains("[EVALUATE NOW]")
    )
    guard configuration.activity == .learn else {
      return evidenceContext
    }

    guard let plan else { return evidenceContext }
    return [evidenceContext, StudyPlanContextBuilder.makeContext(plan: plan)]
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")
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
    activity: KnowledgeActivity,
    plan: StudyPlan?
  ) -> String {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if isStudyPlanGeneration(trimmed) {
      return """
        README overview architecture entry point modules packages dependencies \
        state data flow persistence services tests configuration
        """
    }
    if activity == .learn, let plan {
      if trimmed.localizedCaseInsensitiveContains("[STUDY PLAN NEXT]"),
         let item = plan.nextIncompleteItem {
        return retrievalQuery(for: item)
      }
      if let itemID = requestedStudyPlanItemID(in: trimmed),
         let item = plan.items.first(where: { $0.id == itemID }) {
        return retrievalQuery(for: item)
      }
      if trimmed.localizedCaseInsensitiveContains("[STUDY PLAN RANDOM]") {
        return plan.items
          .filter { !$0.isCompleted }
          .prefix(8)
          .flatMap { [$0.title] + $0.topics + $0.sourcePaths }
          .joined(separator: " ")
      }
    }
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

  private static func isStudyPlanGeneration(_ query: String) -> Bool {
    query.localizedCaseInsensitiveContains("[CREATE STUDY PLAN]")
  }

  private static func requestedStudyPlanItemID(in query: String) -> String? {
    let marker = "[STUDY PLAN ITEM:"
    guard let markerRange = query.range(of: marker, options: .caseInsensitive),
          let end = query[markerRange.upperBound...].firstIndex(of: "]") else {
      return nil
    }
    let itemID = query[markerRange.upperBound..<end]
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return itemID.isEmpty ? nil : itemID
  }

  private static func retrievalQuery(for item: StudyPlanItem) -> String {
    ([item.title, item.objective] + item.topics + item.sourcePaths)
      .joined(separator: " ")
  }

  private func studyPlanEvidence(
    studySpaceID: String,
    query: String
  ) async -> [KnowledgeSearchResult] {
    let ranked = (try? await storage.search(
      studySpaceID: studySpaceID,
      query: query,
      limit: 16
    )) ?? []
    let browsed = (try? await storage.chunks(
      studySpaceID: studySpaceID,
      limit: 240
    )) ?? []

    var seenChunkIDs = Set(ranked.map(\.chunk.id))
    var seenPaths = Set(ranked.map(\.chunk.relativePath))
    var evidence = ranked
    for chunk in browsed where !seenPaths.contains(chunk.relativePath) {
      guard seenChunkIDs.insert(chunk.id).inserted else { continue }
      seenPaths.insert(chunk.relativePath)
      evidence.append(KnowledgeSearchResult(chunk: chunk, score: 0))
      if evidence.count == 40 {
        break
      }
    }
    return evidence
  }

  private func reloadStudyPlans() async throws {
    studyPlans = try await storage.studyPlans()
  }
}
