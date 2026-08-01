//
//  InterviewSQLiteStorage.swift
//  InterviewKit
//
//  SQLite-backed question bank / attempt / evaluation store, patterned on
//  SimplifiedClaudeCodeSQLiteStorage. DB lives at
//  ~/Library/Application Support/CodingBuddy/interview_bank.sqlite.
//

import Foundation
import SQLite

public actor InterviewSQLiteStorage: InterviewStorageProtocol {

  private var database: Connection!
  private var isInitialized = false
  private let applicationSupportDirectory: URL?

  /// Pass a custom directory for tests; nil uses the real Application Support dir.
  public init(applicationSupportDirectory: URL? = nil) {
    self.applicationSupportDirectory = applicationSupportDirectory
  }

  // MARK: - Topic seeding

  static let seedTopics: [Topic] = {
    let algorithms = [
      "two-pointers", "sliding-window", "binary-search", "dynamic-programming",
      "graphs", "trees", "heaps", "hash-maps", "stacks-queues", "intervals",
      "backtracking", "greedy", "linked-lists", "strings", "math", "bit-manipulation",
    ]
    let systemDesign = ["sd-scalability", "sd-storage", "sd-caching", "sd-queues", "sd-api-design"]
    let behavioral = ["bh-leadership", "bh-conflict", "bh-failure", "bh-collaboration", "bh-ownership"]

    func displayName(_ slug: String) -> String {
      slug
        .replacingOccurrences(of: "sd-", with: "")
        .replacingOccurrences(of: "bh-", with: "")
        .split(separator: "-")
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
    }

    var topics: [Topic] = []
    for (index, slug) in algorithms.enumerated() {
      topics.append(Topic(id: slug, displayName: displayName(slug), category: "algorithms", sortOrder: index))
    }
    for (index, slug) in systemDesign.enumerated() {
      topics.append(Topic(id: slug, displayName: displayName(slug), category: "system-design", sortOrder: index))
    }
    for (index, slug) in behavioral.enumerated() {
      topics.append(Topic(id: slug, displayName: displayName(slug), category: "behavioral", sortOrder: index))
    }
    return topics
  }()

  // MARK: - Initialization

  private func initializeDatabaseIfNeeded() throws {
    guard !isInitialized else { return }

    let fileManager = FileManager.default
    let appSupportDir: URL
    if let applicationSupportDirectory {
      appSupportDir = applicationSupportDirectory
    } else {
      appSupportDir = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
    }

    let appDir = appSupportDir.appendingPathComponent("CodingBuddy", isDirectory: true)
    try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)

    let dbPath = appDir.appendingPathComponent("interview_bank.sqlite").path
    database = try Connection(dbPath)
    try database.execute("PRAGMA foreign_keys = ON")

    let migrationManager = InterviewSQLiteMigrationManager(database: database, databasePath: dbPath)
    try migrationManager.runMigrationsIfNeeded()
    try migrationManager.validateDatabase()
    try migrationManager.cleanupOldBackups()

    try seedTopicsIfNeeded()

    isInitialized = true
  }

  private func seedTopicsIfNeeded() throws {
    let seeded = try database.scalar(
      "SELECT value FROM app_meta WHERE key = 'topics_seeded'"
    ) as? String
    guard seeded != "1" else { return }

    try database.transaction {
      for topic in Self.seedTopics {
        try database.run(
          "INSERT OR IGNORE INTO topics (id, display_name, category, sort_order) VALUES (?, ?, ?, ?)",
          topic.id, topic.displayName, topic.category, topic.sortOrder
        )
      }
      try database.run(
        "INSERT OR REPLACE INTO app_meta (key, value) VALUES ('topics_seeded', '1')"
      )
    }
  }

  // MARK: - Questions

  public func saveQuestion(_ q: Question) async throws {
    try initializeDatabaseIfNeeded()
    try database.transaction {
      // True upsert: OR REPLACE would delete + re-insert, nulling out
      // attempts.question_id via ON DELETE SET NULL.
      try database.run(
        """
        INSERT INTO questions
          (id, created_at, mode, title, prompt_markdown, difficulty, language_hint, reference_notes, source, archived)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'generated', ?)
        ON CONFLICT(id) DO UPDATE SET
          created_at = excluded.created_at,
          mode = excluded.mode,
          title = excluded.title,
          prompt_markdown = excluded.prompt_markdown,
          difficulty = excluded.difficulty,
          language_hint = excluded.language_hint,
          reference_notes = excluded.reference_notes,
          archived = excluded.archived
        """,
        q.id, q.createdAt.timeIntervalSince1970, q.mode.rawValue, q.title,
        q.promptMarkdown, q.difficulty.rawValue, q.languageHint, q.referenceNotes,
        q.archived ? 1 : 0
      )
      try database.run("DELETE FROM question_topics WHERE question_id = ?", q.id)
      for topicId in q.topicIds {
        // Unknown topic slugs are auto-registered under a generic category so
        // the FK holds and the dashboard can still group by them.
        try database.run(
          "INSERT OR IGNORE INTO topics (id, display_name, category, sort_order) VALUES (?, ?, 'algorithms', 999)",
          topicId, topicId
        )
        try database.run(
          "INSERT OR IGNORE INTO question_topics (question_id, topic_id) VALUES (?, ?)",
          q.id, topicId
        )
      }
    }
  }

  public func questions(
    mode: SessionMode?,
    topicId: String?,
    difficulty: Difficulty?
  ) async throws -> [Question] {
    try initializeDatabaseIfNeeded()

    var sql = """
      SELECT DISTINCT q.id, q.created_at, q.mode, q.title, q.prompt_markdown,
             q.difficulty, q.language_hint, q.reference_notes, q.archived
      FROM questions q
      """
    var clauses: [String] = ["q.archived = 0"]
    var bindings: [Binding?] = []

    if topicId != nil {
      sql += " JOIN question_topics qt ON qt.question_id = q.id"
      clauses.append("qt.topic_id = ?")
    }
    if mode != nil { clauses.append("q.mode = ?") }
    if difficulty != nil { clauses.append("q.difficulty = ?") }

    sql += " WHERE " + clauses.joined(separator: " AND ")
    sql += " ORDER BY q.created_at DESC"

    if let topicId { bindings.append(topicId) }
    if let mode { bindings.append(mode.rawValue) }
    if let difficulty { bindings.append(difficulty.rawValue) }

    var results: [Question] = []
    for row in try database.prepare(sql, bindings) {
      guard let question = try questionFromRow(row) else { continue }
      results.append(question)
    }
    return results
  }

  public func question(id: String) async throws -> Question? {
    try initializeDatabaseIfNeeded()
    let sql = """
      SELECT q.id, q.created_at, q.mode, q.title, q.prompt_markdown,
             q.difficulty, q.language_hint, q.reference_notes, q.archived
      FROM questions q WHERE q.id = ?
      """
    for row in try database.prepare(sql, [id]) {
      return try questionFromRow(row)
    }
    return nil
  }

  private func questionFromRow(_ row: Statement.Element) throws -> Question? {
    guard
      let id = row[0] as? String,
      let createdAt = row[1] as? Double,
      let modeRaw = row[2] as? String,
      let mode = SessionMode(rawValue: modeRaw),
      let title = row[3] as? String,
      let promptMarkdown = row[4] as? String,
      let difficultyRaw = row[5] as? String,
      let difficulty = Difficulty(rawValue: difficultyRaw)
    else { return nil }

    var topicIds: [String] = []
    for topicRow in try database.prepare(
      "SELECT topic_id FROM question_topics WHERE question_id = ? ORDER BY topic_id", [id]
    ) {
      if let topicId = topicRow[0] as? String {
        topicIds.append(topicId)
      }
    }

    return Question(
      id: id,
      createdAt: Date(timeIntervalSince1970: createdAt),
      mode: mode,
      title: title,
      promptMarkdown: promptMarkdown,
      difficulty: difficulty,
      topicIds: topicIds,
      languageHint: row[6] as? String,
      referenceNotes: row[7] as? String,
      archived: (row[8] as? Int64 ?? 0) == 1
    )
  }

  // MARK: - Attempts

  public func createAttempt(_ a: InterviewAttempt) async throws {
    try initializeDatabaseIfNeeded()
    try runAttemptUpsert(a)
  }

  public func updateAttempt(_ a: InterviewAttempt) async throws {
    try initializeDatabaseIfNeeded()
    try runAttemptUpsert(a)
  }

  private func runAttemptUpsert(_ a: InterviewAttempt) throws {
    // True upsert: INSERT OR REPLACE would delete + re-insert the row, which
    // cascades away this attempt's evaluation.
    try database.run(
      """
      INSERT INTO attempts
        (id, question_id, chat_session_id, provider, mode, status, started_at,
         ended_at, planned_duration_seconds, hint_budget, hints_used, workspace_path)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        question_id = excluded.question_id,
        chat_session_id = excluded.chat_session_id,
        provider = excluded.provider,
        mode = excluded.mode,
        status = excluded.status,
        started_at = excluded.started_at,
        ended_at = excluded.ended_at,
        planned_duration_seconds = excluded.planned_duration_seconds,
        hint_budget = excluded.hint_budget,
        hints_used = excluded.hints_used,
        workspace_path = excluded.workspace_path
      """,
      a.id, a.questionId, a.chatSessionId, a.provider, a.mode.rawValue,
      a.status.rawValue, a.startedAt.timeIntervalSince1970,
      a.endedAt?.timeIntervalSince1970, a.plannedDurationSeconds,
      a.hintBudget, a.hintsUsed, a.workspacePath
    )
  }

  public func linkChatSession(attemptId: String, chatSessionId: String) async throws {
    try initializeDatabaseIfNeeded()
    try database.run(
      "UPDATE attempts SET chat_session_id = ? WHERE id = ?",
      chatSessionId, attemptId
    )
  }

  public func attempts(limit: Int?) async throws -> [InterviewAttempt] {
    try initializeDatabaseIfNeeded()
    var sql = """
      SELECT id, question_id, chat_session_id, provider, mode, status, started_at,
             ended_at, planned_duration_seconds, hint_budget, hints_used, workspace_path
      FROM attempts ORDER BY started_at DESC
      """
    if let limit { sql += " LIMIT \(limit)" }

    var results: [InterviewAttempt] = []
    for row in try database.prepare(sql) {
      if let attempt = attemptFromRow(row) {
        results.append(attempt)
      }
    }
    return results
  }

  public func attempt(id: String) async throws -> InterviewAttempt? {
    try initializeDatabaseIfNeeded()
    let sql = """
      SELECT id, question_id, chat_session_id, provider, mode, status, started_at,
             ended_at, planned_duration_seconds, hint_budget, hints_used, workspace_path
      FROM attempts WHERE id = ?
      """
    for row in try database.prepare(sql, [id]) {
      return attemptFromRow(row)
    }
    return nil
  }

  public func attempt(forChatSessionId chatSessionId: String) async throws -> InterviewAttempt? {
    try initializeDatabaseIfNeeded()
    let sql = """
      SELECT id, question_id, chat_session_id, provider, mode, status, started_at,
             ended_at, planned_duration_seconds, hint_budget, hints_used, workspace_path
      FROM attempts WHERE chat_session_id = ? ORDER BY started_at DESC LIMIT 1
      """
    for row in try database.prepare(sql, [chatSessionId]) {
      return attemptFromRow(row)
    }
    return nil
  }

  private func attemptFromRow(_ row: Statement.Element) -> InterviewAttempt? {
    guard
      let id = row[0] as? String,
      let provider = row[3] as? String,
      let modeRaw = row[4] as? String,
      let mode = SessionMode(rawValue: modeRaw),
      let statusRaw = row[5] as? String,
      let status = InterviewAttempt.Status(rawValue: statusRaw),
      let startedAt = row[6] as? Double
    else { return nil }

    return InterviewAttempt(
      id: id,
      questionId: row[1] as? String,
      chatSessionId: row[2] as? String,
      provider: provider,
      mode: mode,
      status: status,
      startedAt: Date(timeIntervalSince1970: startedAt),
      endedAt: (row[7] as? Double).map(Date.init(timeIntervalSince1970:)),
      plannedDurationSeconds: (row[8] as? Int64).map(Int.init),
      hintBudget: Int(row[9] as? Int64 ?? 0),
      hintsUsed: Int(row[10] as? Int64 ?? 0),
      workspacePath: row[11] as? String
    )
  }

  // MARK: - Evaluations

  public func saveEvaluation(_ e: RubricEvaluation, notes: [ImprovementNote]) async throws {
    try initializeDatabaseIfNeeded()
    try database.transaction {
      // attempt_id is UNIQUE: replace any previous evaluation for this attempt.
      try database.run("DELETE FROM evaluations WHERE attempt_id = ?", e.attemptId)
      try database.run(
        """
        INSERT INTO evaluations
          (id, attempt_id, created_at, overall_score, verdict, summary_markdown, raw_json)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        e.id, e.attemptId, e.createdAt.timeIntervalSince1970,
        e.overallScore, e.verdict, e.summaryMarkdown, e.rawJSON
      )
      for score in e.dimensionScores {
        try database.run(
          """
          INSERT OR REPLACE INTO evaluation_scores
            (evaluation_id, dimension, score, max_score, comment)
          VALUES (?, ?, ?, ?, ?)
          """,
          e.id, score.dimension, score.score, score.maxScore, score.comment
        )
      }
      for note in notes {
        try database.run(
          "INSERT OR IGNORE INTO topics (id, display_name, category, sort_order) SELECT ?, ?, 'algorithms', 999 WHERE ? IS NOT NULL",
          note.topicId, note.topicId, note.topicId
        )
        try database.run(
          """
          INSERT OR REPLACE INTO improvement_notes
            (id, attempt_id, topic_id, created_at, note_markdown, is_resolved)
          VALUES (?, ?, ?, ?, ?, ?)
          """,
          note.id, note.attemptId, note.topicId,
          note.createdAt.timeIntervalSince1970, note.noteMarkdown,
          note.isResolved ? 1 : 0
        )
      }
    }
  }

  public func evaluation(forAttemptId attemptId: String) async throws -> RubricEvaluation? {
    try initializeDatabaseIfNeeded()
    let sql = """
      SELECT id, attempt_id, created_at, overall_score, verdict, summary_markdown, raw_json
      FROM evaluations WHERE attempt_id = ?
      """
    for row in try database.prepare(sql, [attemptId]) {
      guard
        let id = row[0] as? String,
        let attemptId = row[1] as? String,
        let createdAt = row[2] as? Double,
        let overallScore = row[3] as? Double,
        let summaryMarkdown = row[5] as? String,
        let rawJSON = row[6] as? String
      else { continue }

      var scores: [DimensionScore] = []
      for scoreRow in try database.prepare(
        "SELECT dimension, score, max_score, comment FROM evaluation_scores WHERE evaluation_id = ?",
        [id]
      ) {
        guard
          let dimension = scoreRow[0] as? String,
          let score = scoreRow[1] as? Double,
          let maxScore = scoreRow[2] as? Double
        else { continue }
        scores.append(DimensionScore(
          dimension: dimension,
          score: score,
          maxScore: maxScore,
          comment: scoreRow[3] as? String
        ))
      }

      return RubricEvaluation(
        id: id,
        attemptId: attemptId,
        createdAt: Date(timeIntervalSince1970: createdAt),
        overallScore: overallScore,
        verdict: row[4] as? String,
        summaryMarkdown: summaryMarkdown,
        dimensionScores: scores,
        rawJSON: rawJSON
      )
    }
    return nil
  }

  // MARK: - Improvement notes

  public func openImprovementNotes() async throws -> [ImprovementNote] {
    try initializeDatabaseIfNeeded()
    let sql = """
      SELECT id, attempt_id, topic_id, created_at, note_markdown, is_resolved
      FROM improvement_notes WHERE is_resolved = 0 ORDER BY created_at DESC
      """
    var results: [ImprovementNote] = []
    for row in try database.prepare(sql) {
      guard
        let id = row[0] as? String,
        let createdAt = row[3] as? Double,
        let noteMarkdown = row[4] as? String
      else { continue }
      results.append(ImprovementNote(
        id: id,
        attemptId: row[1] as? String,
        topicId: row[2] as? String,
        createdAt: Date(timeIntervalSince1970: createdAt),
        noteMarkdown: noteMarkdown,
        isResolved: (row[5] as? Int64 ?? 0) == 1
      ))
    }
    return results
  }

  public func notes(forAttemptId attemptId: String) async throws -> [ImprovementNote] {
    try initializeDatabaseIfNeeded()
    let sql = """
      SELECT id, attempt_id, topic_id, created_at, note_markdown, is_resolved
      FROM improvement_notes WHERE attempt_id = ? ORDER BY created_at ASC
      """
    var results: [ImprovementNote] = []
    for row in try database.prepare(sql, [attemptId]) {
      guard
        let id = row[0] as? String,
        let createdAt = row[3] as? Double,
        let noteMarkdown = row[4] as? String
      else { continue }
      results.append(ImprovementNote(
        id: id,
        attemptId: row[1] as? String,
        topicId: row[2] as? String,
        createdAt: Date(timeIntervalSince1970: createdAt),
        noteMarkdown: noteMarkdown,
        isResolved: (row[5] as? Int64 ?? 0) == 1
      ))
    }
    return results
  }

  public func setNoteResolved(id: String, resolved: Bool) async throws {
    try initializeDatabaseIfNeeded()
    try database.run(
      "UPDATE improvement_notes SET is_resolved = ? WHERE id = ?",
      resolved ? 1 : 0, id
    )
  }

  // MARK: - Topics / stats

  public func allTopics() async throws -> [Topic] {
    try initializeDatabaseIfNeeded()
    var results: [Topic] = []
    for row in try database.prepare(
      "SELECT id, display_name, category, sort_order FROM topics ORDER BY category, sort_order"
    ) {
      guard
        let id = row[0] as? String,
        let displayName = row[1] as? String,
        let category = row[2] as? String
      else { continue }
      results.append(Topic(
        id: id,
        displayName: displayName,
        category: category,
        sortOrder: Int(row[3] as? Int64 ?? 0)
      ))
    }
    return results
  }

  public func topicSkillStats() async throws -> [TopicSkillStat] {
    try initializeDatabaseIfNeeded()

    var stats: [String: TopicSkillStat] = [:]
    for row in try database.prepare(
      "SELECT topic_id, attempt_count, avg_score, last_attempt_at FROM topic_skill_stats"
    ) {
      guard let topicId = row[0] as? String else { continue }
      stats[topicId] = TopicSkillStat(
        topicId: topicId,
        attemptCount: Int(row[1] as? Int64 ?? 0),
        averageScore: row[2] as? Double,
        lastAttemptAt: (row[3] as? Double).map(Date.init(timeIntervalSince1970:))
      )
    }

    // Per-attempt trend points, oldest first.
    let trendSQL = """
      SELECT qt.topic_id, a.started_at, e.overall_score
      FROM attempts a
      JOIN questions q        ON q.id = a.question_id
      JOIN question_topics qt ON qt.question_id = q.id
      JOIN evaluations e      ON e.attempt_id = a.id
      WHERE a.status = 'evaluated'
      ORDER BY a.started_at ASC
      """
    for row in try database.prepare(trendSQL) {
      guard
        let topicId = row[0] as? String,
        let startedAt = row[1] as? Double,
        let score = row[2] as? Double,
        var stat = stats[topicId]
      else { continue }
      stat.trend.append(ScorePoint(date: Date(timeIntervalSince1970: startedAt), overallScore: score))
      stats[topicId] = stat
    }

    return stats.values.sorted { $0.topicId < $1.topicId }
  }
}
