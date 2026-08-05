//
//  InterviewSQLiteMigrations.swift
//  InterviewKit
//
//  Migration manager for interview_bank.sqlite, patterned on
//  SimplifiedClaudeCodeSQLiteMigrationManager: PRAGMA user_version tracking,
//  VACUUM INTO backup before any migration, fresh-DB fast path.
//

import Foundation
import SQLite

public enum InterviewMigrationError: LocalizedError {
  case downgradeNotSupported(current: Int64, target: Int64)
  case integrityCheckFailed(String)

  public var errorDescription: String? {
    switch self {
    case .downgradeNotSupported(let current, let target):
      return "Database schema version \(current) is newer than supported version \(target)."
    case .integrityCheckFailed(let detail):
      return "Database integrity check failed: \(detail)"
    }
  }
}

final class InterviewSQLiteMigrationManager {

  static let currentSchemaVersion: Int64 = 1

  private let database: Connection
  private let databasePath: String

  init(database: Connection, databasePath: String) {
    self.database = database
    self.databasePath = databasePath
  }

  private var schemaVersion: Int64 {
    get throws {
      try database.scalar("PRAGMA user_version") as? Int64 ?? 0
    }
  }

  private func setSchemaVersion(_ version: Int64) throws {
    try database.execute("PRAGMA user_version = \(version)")
  }

  func runMigrationsIfNeeded() throws {
    let version = try schemaVersion

    if version == Self.currentSchemaVersion {
      return
    }

    if version > Self.currentSchemaVersion {
      throw InterviewMigrationError.downgradeNotSupported(
        current: version,
        target: Self.currentSchemaVersion
      )
    }

    // Fresh database: create the schema directly, no backup needed.
    if version == 0 && isFreshDatabase() {
      try createSchemaV1()
      try setSchemaVersion(Self.currentSchemaVersion)
      return
    }

    try backupDatabase()

    var migratingVersion = version
    while migratingVersion < Self.currentSchemaVersion {
      switch migratingVersion {
      case 0:
        try createSchemaV1()
      default:
        break
      }
      migratingVersion += 1
      try setSchemaVersion(migratingVersion)
    }
  }

  func validateDatabase() throws {
    let result = try database.scalar("PRAGMA integrity_check") as? String
    guard result == "ok" else {
      throw InterviewMigrationError.integrityCheckFailed(result ?? "unknown")
    }
  }

  func cleanupOldBackups(keeping keepCount: Int = 3) throws {
    let directory = (databasePath as NSString).deletingLastPathComponent
    let baseName = (databasePath as NSString).lastPathComponent
    let fileManager = FileManager.default
    let contents = (try? fileManager.contentsOfDirectory(atPath: directory)) ?? []
    let backups = contents
      .filter { $0.hasPrefix("\(baseName).backup-") }
      .sorted(by: >)
    for backup in backups.dropFirst(keepCount) {
      try? fileManager.removeItem(atPath: (directory as NSString).appendingPathComponent(backup))
    }
  }

  // MARK: - Private

  private func isFreshDatabase() -> Bool {
    let tableCount = (try? database.scalar(
      "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
    ) as? Int64) ?? 0
    return tableCount == 0
  }

  private func backupDatabase() throws {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let backupPath = "\(databasePath).backup-\(formatter.string(from: Date()))"
    try database.execute("VACUUM INTO '\(backupPath)'")
  }

  private func createSchemaV1() throws {
    try database.execute("""
      CREATE TABLE IF NOT EXISTS topics (
        id           TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        category     TEXT NOT NULL,
        sort_order   INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS questions (
        id              TEXT PRIMARY KEY,
        created_at      REAL NOT NULL,
        mode            TEXT NOT NULL,
        title           TEXT NOT NULL,
        prompt_markdown TEXT NOT NULL,
        difficulty      TEXT NOT NULL,
        language_hint   TEXT,
        reference_notes TEXT,
        source          TEXT NOT NULL DEFAULT 'generated',
        archived        INTEGER NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS question_topics (
        question_id TEXT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
        topic_id    TEXT NOT NULL REFERENCES topics(id)    ON DELETE CASCADE,
        PRIMARY KEY (question_id, topic_id)
      );

      CREATE TABLE IF NOT EXISTS attempts (
        id                       TEXT PRIMARY KEY,
        question_id              TEXT REFERENCES questions(id) ON DELETE SET NULL,
        chat_session_id          TEXT,
        provider                 TEXT NOT NULL,
        mode                     TEXT NOT NULL,
        status                   TEXT NOT NULL DEFAULT 'in_progress',
        started_at               REAL NOT NULL,
        ended_at                 REAL,
        planned_duration_seconds INTEGER,
        hint_budget              INTEGER NOT NULL DEFAULT 0,
        hints_used               INTEGER NOT NULL DEFAULT 0,
        workspace_path           TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_attempts_started_at   ON attempts(started_at);
      CREATE INDEX IF NOT EXISTS idx_attempts_mode         ON attempts(mode);
      CREATE INDEX IF NOT EXISTS idx_attempts_chat_session ON attempts(chat_session_id);

      CREATE TABLE IF NOT EXISTS evaluations (
        id               TEXT PRIMARY KEY,
        attempt_id       TEXT NOT NULL UNIQUE REFERENCES attempts(id) ON DELETE CASCADE,
        created_at       REAL NOT NULL,
        overall_score    REAL NOT NULL,
        summary_markdown TEXT NOT NULL,
        raw_json         TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS evaluation_scores (
        evaluation_id TEXT NOT NULL REFERENCES evaluations(id) ON DELETE CASCADE,
        dimension     TEXT NOT NULL,
        score         REAL NOT NULL,
        max_score     REAL NOT NULL DEFAULT 10,
        comment       TEXT,
        PRIMARY KEY (evaluation_id, dimension)
      );

      CREATE TABLE IF NOT EXISTS improvement_notes (
        id            TEXT PRIMARY KEY,
        attempt_id    TEXT REFERENCES attempts(id) ON DELETE CASCADE,
        topic_id      TEXT REFERENCES topics(id)   ON DELETE SET NULL,
        created_at    REAL NOT NULL,
        note_markdown TEXT NOT NULL,
        is_resolved   INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS idx_notes_topic ON improvement_notes(topic_id);

      CREATE TABLE IF NOT EXISTS app_meta ( key TEXT PRIMARY KEY, value TEXT NOT NULL );

      CREATE VIEW IF NOT EXISTS topic_skill_stats AS
      SELECT qt.topic_id,
             COUNT(DISTINCT a.id) AS attempt_count,
             AVG(e.overall_score) AS avg_score,
             MAX(a.started_at)    AS last_attempt_at
      FROM attempts a
      JOIN questions q        ON q.id = a.question_id
      JOIN question_topics qt ON qt.question_id = q.id
      LEFT JOIN evaluations e ON e.attempt_id = a.id
      WHERE a.status = 'evaluated'
      GROUP BY qt.topic_id;

      CREATE VIEW IF NOT EXISTS weekly_score_trend AS
      SELECT strftime('%Y-%W', a.started_at, 'unixepoch') AS week,
             a.mode, AVG(e.overall_score) AS avg_score, COUNT(*) AS attempts
      FROM attempts a JOIN evaluations e ON e.attempt_id = a.id
      GROUP BY week, a.mode;
      """)
  }
}
