import Foundation
import SQLite

public actor SQLiteKnowledgeStorage: KnowledgeStorageProtocol {
  private var database: Connection!
  private var isInitialized = false
  private let applicationSupportDirectory: URL?

  public init(applicationSupportDirectory: URL? = nil) {
    self.applicationSupportDirectory = applicationSupportDirectory
  }

  public func saveStudySpace(_ studySpace: StudySpace) async throws {
    try initializeIfNeeded()
    try database.run(
      """
      INSERT INTO study_spaces (id, name, created_at, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        updated_at = excluded.updated_at
      """,
      studySpace.id,
      studySpace.name,
      studySpace.createdAt.timeIntervalSince1970,
      studySpace.updatedAt.timeIntervalSince1970
    )
  }

  public func studySpaces() async throws -> [StudySpace] {
    try initializeIfNeeded()
    var results: [StudySpace] = []
    for row in try database.prepare(
      "SELECT id, name, created_at, updated_at FROM study_spaces ORDER BY updated_at DESC"
    ) {
      guard let studySpace = studySpace(from: row) else { continue }
      results.append(studySpace)
    }
    return results
  }

  public func studySpace(id: String) async throws -> StudySpace? {
    try initializeIfNeeded()
    for row in try database.prepare(
      "SELECT id, name, created_at, updated_at FROM study_spaces WHERE id = ?",
      [id]
    ) {
      return studySpace(from: row)
    }
    return nil
  }

  public func deleteStudySpace(id: String) async throws {
    try initializeIfNeeded()
    try database.transaction {
      try database.run("DELETE FROM knowledge_fts WHERE study_space_id = ?", id)
      try database.run("DELETE FROM study_spaces WHERE id = ?", id)
    }
  }

  public func saveStudyPlan(_ studyPlan: StudyPlan) async throws {
    try initializeIfNeeded()
    try database.transaction {
      try database.run(
        """
        INSERT INTO study_plans (
          id, study_space_id, title, summary, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          summary = excluded.summary,
          updated_at = excluded.updated_at
        """,
        studyPlan.id,
        studyPlan.studySpaceID,
        studyPlan.title,
        studyPlan.summary,
        studyPlan.createdAt.timeIntervalSince1970,
        studyPlan.updatedAt.timeIntervalSince1970
      )
      try database.run("DELETE FROM study_plan_items WHERE plan_id = ?", studyPlan.id)

      for (index, item) in studyPlan.items.enumerated() {
        try database.run(
          """
          INSERT INTO study_plan_items (
            plan_id, item_id, order_index, section_title, title, objective,
            topics_json, source_paths_json, prerequisite_ids_json,
            is_completed, completed_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          """,
          studyPlan.id,
          item.id,
          index,
          item.section,
          item.title,
          item.objective,
          try encodedStringArray(item.topics),
          try encodedStringArray(item.sourcePaths),
          try encodedStringArray(item.prerequisiteIDs),
          item.isCompleted ? 1 : 0,
          item.completedAt?.timeIntervalSince1970
        )
      }
    }
  }

  public func studyPlans() async throws -> [StudyPlan] {
    try initializeIfNeeded()
    let sql = """
      SELECT id, study_space_id, title, summary, created_at, updated_at
      FROM study_plans
      ORDER BY updated_at DESC
      """
    var plans: [StudyPlan] = []
    for row in try database.prepare(sql) {
      guard let plan = try studyPlan(from: row) else { continue }
      plans.append(plan)
    }
    return plans
  }

  public func studyPlan(studySpaceID: String) async throws -> StudyPlan? {
    try initializeIfNeeded()
    let sql = """
      SELECT id, study_space_id, title, summary, created_at, updated_at
      FROM study_plans
      WHERE study_space_id = ?
      LIMIT 1
      """
    for row in try database.prepare(sql, [studySpaceID]) {
      return try studyPlan(from: row)
    }
    return nil
  }

  public func setStudyPlanItemCompletion(
    planID: String,
    itemID: String,
    isCompleted: Bool,
    completedAt: Date?
  ) async throws {
    try initializeIfNeeded()
    try database.transaction {
      try database.run(
        """
        UPDATE study_plan_items
        SET is_completed = ?, completed_at = ?
        WHERE plan_id = ? AND item_id = ?
        """,
        isCompleted ? 1 : 0,
        completedAt?.timeIntervalSince1970,
        planID,
        itemID
      )
      try database.run(
        "UPDATE study_plans SET updated_at = ? WHERE id = ?",
        Date.now.timeIntervalSince1970,
        planID
      )
    }
  }

  public func deleteStudyPlan(id: String) async throws {
    try initializeIfNeeded()
    try database.run("DELETE FROM study_plans WHERE id = ?", id)
  }

  public func saveSource(_ source: KnowledgeSource) async throws {
    try initializeIfNeeded()
    try database.run(
      """
      INSERT INTO knowledge_sources (
        id, study_space_id, kind, display_name, root_path, index_status,
        indexed_file_count, chunk_count, indexed_at, content_version, error_message
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        display_name = excluded.display_name,
        root_path = excluded.root_path,
        index_status = excluded.index_status,
        indexed_file_count = excluded.indexed_file_count,
        chunk_count = excluded.chunk_count,
        indexed_at = excluded.indexed_at,
        content_version = excluded.content_version,
        error_message = excluded.error_message
      """,
      source.id,
      source.studySpaceID,
      source.kind.rawValue,
      source.displayName,
      source.rootPath,
      source.indexStatus.rawValue,
      source.indexedFileCount,
      source.chunkCount,
      source.indexedAt?.timeIntervalSince1970,
      source.contentVersion,
      source.errorMessage
    )
  }

  public func sources(studySpaceID: String) async throws -> [KnowledgeSource] {
    try initializeIfNeeded()
    let sql = """
      SELECT id, study_space_id, kind, display_name, root_path, index_status,
             indexed_file_count, chunk_count, indexed_at, content_version, error_message
      FROM knowledge_sources
      WHERE study_space_id = ?
      ORDER BY display_name COLLATE NOCASE
      """
    var results: [KnowledgeSource] = []
    for row in try database.prepare(sql, [studySpaceID]) {
      guard let source = source(from: row) else { continue }
      results.append(source)
    }
    return results
  }

  public func replaceChunks(for sourceID: String, with chunks: [KnowledgeChunk]) async throws {
    try initializeIfNeeded()
    try database.transaction {
      try database.run("DELETE FROM knowledge_fts WHERE source_id = ?", sourceID)
      try database.run("DELETE FROM knowledge_chunks WHERE source_id = ?", sourceID)

      for chunk in chunks {
        try database.run(
          """
          INSERT INTO knowledge_chunks (
            id, study_space_id, source_id, relative_path, start_line, end_line,
            content, content_hash
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          """,
          chunk.id,
          chunk.studySpaceID,
          chunk.sourceID,
          chunk.relativePath,
          chunk.startLine,
          chunk.endLine,
          chunk.content,
          chunk.contentHash
        )
        try database.run(
          """
          INSERT INTO knowledge_fts (
            chunk_id, study_space_id, source_id, relative_path, content
          ) VALUES (?, ?, ?, ?, ?)
          """,
          chunk.id,
          chunk.studySpaceID,
          chunk.sourceID,
          chunk.relativePath,
          chunk.content
        )
      }
    }
  }

  public func chunks(studySpaceID: String, limit: Int) async throws -> [KnowledgeChunk] {
    try initializeIfNeeded()
    let sql = """
      SELECT id, study_space_id, source_id, relative_path, start_line, end_line,
             content, content_hash
      FROM knowledge_chunks
      WHERE study_space_id = ?
      ORDER BY relative_path COLLATE NOCASE, start_line
      LIMIT ?
      """
    var results: [KnowledgeChunk] = []
    let bindings: [Binding?] = [studySpaceID, Int64(max(1, limit))]
    for row in try database.prepare(sql, bindings) {
      guard let chunk = chunk(from: row) else { continue }
      results.append(chunk)
    }
    return results
  }

  public func chunk(id: String) async throws -> KnowledgeChunk? {
    try initializeIfNeeded()
    let sql = """
      SELECT id, study_space_id, source_id, relative_path, start_line, end_line,
             content, content_hash
      FROM knowledge_chunks WHERE id = ?
      """
    for row in try database.prepare(sql, [id]) {
      return chunk(from: row)
    }
    return nil
  }

  public func search(
    studySpaceID: String,
    query: String,
    limit: Int
  ) async throws -> [KnowledgeSearchResult] {
    try initializeIfNeeded()
    let tokens = Self.ftsTokens(query)
    guard !tokens.isEmpty else { return [] }

    // Prefer passages matching every term; when that comes up empty (common
    // for exploratory multi-word queries) fall back to any-term matches so
    // the user still gets ranked results instead of a dead end.
    let allTerms = try runSearch(
      matching: tokens.joined(separator: " "),
      studySpaceID: studySpaceID,
      limit: limit
    )
    if !allTerms.isEmpty || tokens.count == 1 {
      return allTerms
    }
    return try runSearch(
      matching: tokens.joined(separator: " OR "),
      studySpaceID: studySpaceID,
      limit: limit
    )
  }

  private func runSearch(
    matching ftsQuery: String,
    studySpaceID: String,
    limit: Int
  ) throws -> [KnowledgeSearchResult] {
    let sql = """
      SELECT c.id, c.study_space_id, c.source_id, c.relative_path,
             c.start_line, c.end_line, c.content, c.content_hash,
             bm25(knowledge_fts, 0.0, 0.0, 0.0, 4.0, 1.0) AS rank
      FROM knowledge_fts
      JOIN knowledge_chunks c ON c.id = knowledge_fts.chunk_id
      WHERE knowledge_fts MATCH ? AND knowledge_fts.study_space_id = ?
      ORDER BY rank
      LIMIT ?
      """
    let bindings: [Binding?] = [ftsQuery, studySpaceID, Int64(max(1, limit))]
    var results: [KnowledgeSearchResult] = []
    for row in try database.prepare(sql, bindings) {
      guard let chunk = chunk(from: row) else { continue }
      let rank = row[8] as? Double ?? 0
      results.append(KnowledgeSearchResult(chunk: chunk, score: -rank))
    }
    return results
  }

  public func saveSessionBinding(_ binding: KnowledgeSessionBinding) async throws {
    try initializeIfNeeded()
    try database.run(
      """
      INSERT INTO knowledge_sessions (
        chat_session_id, study_space_id, activity, source_access, created_at
      ) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(chat_session_id) DO UPDATE SET
        study_space_id = excluded.study_space_id,
        activity = excluded.activity,
        source_access = excluded.source_access
      """,
      binding.chatSessionID,
      binding.configuration.studySpaceID,
      binding.configuration.activity.rawValue,
      binding.configuration.sourceAccess.rawValue,
      binding.createdAt.timeIntervalSince1970
    )
  }

  public func sessionBinding(chatSessionID: String) async throws -> KnowledgeSessionBinding? {
    try initializeIfNeeded()
    let sql = """
      SELECT chat_session_id, study_space_id, activity, source_access, created_at
      FROM knowledge_sessions WHERE chat_session_id = ?
      """
    for row in try database.prepare(sql, [chatSessionID]) {
      guard let chatSessionID = row[0] as? String,
            let studySpaceID = row[1] as? String,
            let activityRaw = row[2] as? String,
            let activity = KnowledgeActivity(rawValue: activityRaw),
            let sourceAccessRaw = row[3] as? String,
            let sourceAccess = KnowledgeSourceAccess(rawValue: sourceAccessRaw),
            let createdAt = row[4] as? Double else {
        return nil
      }
      return KnowledgeSessionBinding(
        chatSessionID: chatSessionID,
        configuration: KnowledgeSessionConfiguration(
          studySpaceID: studySpaceID,
          activity: activity,
          sourceAccess: sourceAccess
        ),
        createdAt: Date(timeIntervalSince1970: createdAt)
      )
    }
    return nil
  }

  public func deleteSessionBinding(chatSessionID: String) async throws {
    try initializeIfNeeded()
    try database.run("DELETE FROM knowledge_sessions WHERE chat_session_id = ?", chatSessionID)
  }

  private func initializeIfNeeded() throws {
    guard !isInitialized else { return }

    let fileManager = FileManager.default
    let supportDirectory: URL
    if let applicationSupportDirectory {
      supportDirectory = applicationSupportDirectory
    } else {
      supportDirectory = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
    }
    let appDirectory = supportDirectory.appendingPathComponent("CodingBuddy", isDirectory: true)
    try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
    let path = appDirectory.appendingPathComponent("knowledge_library.sqlite").path

    database = try Connection(path)
    try database.execute("PRAGMA foreign_keys = ON")
    try database.execute("""
      CREATE TABLE IF NOT EXISTS study_spaces (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
      );

      CREATE TABLE IF NOT EXISTS knowledge_sources (
        id                 TEXT PRIMARY KEY,
        study_space_id     TEXT NOT NULL REFERENCES study_spaces(id) ON DELETE CASCADE,
        kind               TEXT NOT NULL,
        display_name       TEXT NOT NULL,
        root_path          TEXT NOT NULL,
        index_status       TEXT NOT NULL,
        indexed_file_count INTEGER NOT NULL DEFAULT 0,
        chunk_count        INTEGER NOT NULL DEFAULT 0,
        indexed_at         REAL,
        content_version    TEXT,
        error_message      TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_knowledge_sources_space
        ON knowledge_sources(study_space_id);

      CREATE TABLE IF NOT EXISTS study_plans (
        id             TEXT PRIMARY KEY,
        study_space_id TEXT NOT NULL UNIQUE REFERENCES study_spaces(id) ON DELETE CASCADE,
        title          TEXT NOT NULL,
        summary        TEXT NOT NULL,
        created_at     REAL NOT NULL,
        updated_at     REAL NOT NULL
      );

      CREATE TABLE IF NOT EXISTS study_plan_items (
        plan_id              TEXT NOT NULL REFERENCES study_plans(id) ON DELETE CASCADE,
        item_id              TEXT NOT NULL,
        order_index          INTEGER NOT NULL,
        section_title        TEXT NOT NULL,
        title                TEXT NOT NULL,
        objective            TEXT NOT NULL,
        topics_json          TEXT NOT NULL,
        source_paths_json    TEXT NOT NULL,
        prerequisite_ids_json TEXT NOT NULL,
        is_completed         INTEGER NOT NULL DEFAULT 0,
        completed_at         REAL,
        PRIMARY KEY (plan_id, item_id)
      );
      CREATE INDEX IF NOT EXISTS idx_study_plan_items_order
        ON study_plan_items(plan_id, order_index);

      CREATE TABLE IF NOT EXISTS knowledge_chunks (
        id             TEXT PRIMARY KEY,
        study_space_id TEXT NOT NULL REFERENCES study_spaces(id) ON DELETE CASCADE,
        source_id      TEXT NOT NULL REFERENCES knowledge_sources(id) ON DELETE CASCADE,
        relative_path  TEXT NOT NULL,
        start_line     INTEGER NOT NULL,
        end_line       INTEGER NOT NULL,
        content        TEXT NOT NULL,
        content_hash   TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_space
        ON knowledge_chunks(study_space_id);
      CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_source
        ON knowledge_chunks(source_id);

      CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
        chunk_id UNINDEXED,
        study_space_id UNINDEXED,
        source_id UNINDEXED,
        relative_path,
        content,
        tokenize = 'unicode61 remove_diacritics 2'
      );

      CREATE TABLE IF NOT EXISTS knowledge_sessions (
        chat_session_id TEXT PRIMARY KEY,
        study_space_id  TEXT NOT NULL REFERENCES study_spaces(id) ON DELETE CASCADE,
        activity        TEXT NOT NULL,
        source_access   TEXT NOT NULL,
        created_at      REAL NOT NULL
      );
      """)
    isInitialized = true
  }

  private func studySpace(from row: Statement.Element) -> StudySpace? {
    guard let id = row[0] as? String,
          let name = row[1] as? String,
          let createdAt = row[2] as? Double,
          let updatedAt = row[3] as? Double else {
      return nil
    }
    return StudySpace(
      id: id,
      name: name,
      createdAt: Date(timeIntervalSince1970: createdAt),
      updatedAt: Date(timeIntervalSince1970: updatedAt)
    )
  }

  private func source(from row: Statement.Element) -> KnowledgeSource? {
    guard let id = row[0] as? String,
          let studySpaceID = row[1] as? String,
          let kindRaw = row[2] as? String,
          let kind = KnowledgeSourceKind(rawValue: kindRaw),
          let displayName = row[3] as? String,
          let rootPath = row[4] as? String,
          let statusRaw = row[5] as? String,
          let status = KnowledgeIndexStatus(rawValue: statusRaw) else {
      return nil
    }
    return KnowledgeSource(
      id: id,
      studySpaceID: studySpaceID,
      kind: kind,
      displayName: displayName,
      rootPath: rootPath,
      indexStatus: status,
      indexedFileCount: Int(row[6] as? Int64 ?? 0),
      chunkCount: Int(row[7] as? Int64 ?? 0),
      indexedAt: (row[8] as? Double).map(Date.init(timeIntervalSince1970:)),
      contentVersion: row[9] as? String,
      errorMessage: row[10] as? String
    )
  }

  private func studyPlan(from row: Statement.Element) throws -> StudyPlan? {
    guard let id = row[0] as? String,
          let studySpaceID = row[1] as? String,
          let title = row[2] as? String,
          let summary = row[3] as? String,
          let createdAt = row[4] as? Double,
          let updatedAt = row[5] as? Double else {
      return nil
    }

    let itemSQL = """
      SELECT item_id, section_title, title, objective, topics_json,
             source_paths_json, prerequisite_ids_json, is_completed, completed_at
      FROM study_plan_items
      WHERE plan_id = ?
      ORDER BY order_index
      """
    var items: [StudyPlanItem] = []
    for itemRow in try database.prepare(itemSQL, [id]) {
      guard let item = studyPlanItem(from: itemRow) else { continue }
      items.append(item)
    }
    return StudyPlan(
      id: id,
      studySpaceID: studySpaceID,
      title: title,
      summary: summary,
      items: items,
      createdAt: Date(timeIntervalSince1970: createdAt),
      updatedAt: Date(timeIntervalSince1970: updatedAt)
    )
  }

  private func studyPlanItem(from row: Statement.Element) -> StudyPlanItem? {
    guard let id = row[0] as? String,
          let section = row[1] as? String,
          let title = row[2] as? String,
          let objective = row[3] as? String,
          let topicsJSON = row[4] as? String,
          let sourcePathsJSON = row[5] as? String,
          let prerequisiteIDsJSON = row[6] as? String else {
      return nil
    }
    return StudyPlanItem(
      id: id,
      section: section,
      title: title,
      objective: objective,
      topics: decodedStringArray(topicsJSON),
      sourcePaths: decodedStringArray(sourcePathsJSON),
      prerequisiteIDs: decodedStringArray(prerequisiteIDsJSON),
      isCompleted: (row[7] as? Int64 ?? 0) != 0,
      completedAt: (row[8] as? Double).map(Date.init(timeIntervalSince1970:))
    )
  }

  private func encodedStringArray(_ strings: [String]) throws -> String {
    let data = try JSONEncoder().encode(strings)
    return String(decoding: data, as: UTF8.self)
  }

  private func decodedStringArray(_ string: String) -> [String] {
    guard let data = string.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
  }

  private func chunk(from row: Statement.Element) -> KnowledgeChunk? {
    guard let id = row[0] as? String,
          let studySpaceID = row[1] as? String,
          let sourceID = row[2] as? String,
          let relativePath = row[3] as? String,
          let startLine = row[4] as? Int64,
          let endLine = row[5] as? Int64,
          let content = row[6] as? String,
          let contentHash = row[7] as? String else {
      return nil
    }
    return KnowledgeChunk(
      id: id,
      studySpaceID: studySpaceID,
      sourceID: sourceID,
      relativePath: relativePath,
      startLine: Int(startLine),
      endLine: Int(endLine),
      content: content,
      contentHash: contentHash
    )
  }

  /// Sanitized prefix-match terms for FTS5. Symbols are stripped (they are
  /// MATCH syntax), and every term keeps a trailing `*` so search-as-you-type
  /// matches partial identifiers.
  private static func ftsTokens(_ query: String) -> [String] {
    query
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
      .filter { !$0.isEmpty }
      .prefix(16)
      .map { "\"\($0)\"*" }
  }
}
