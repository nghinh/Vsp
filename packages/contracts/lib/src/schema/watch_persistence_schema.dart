// Watch Persistence Schema — VSP Contracts Package
//
// SQLite schema for watch round data persistence.
// Used by watch app for local storage and sync queue.
//
// Story 10.1 — Slice 1/3: Watch Adapter & Data Contracts

/// Watch persistence schema version.
const int watchPersistenceSchemaVersion = 1;

/// SQL statements for watch persistence schema.
abstract class WatchPersistenceSchema {
  /// Create watch_scores table.
  static const String createScoresTable = '''
    CREATE TABLE IF NOT EXISTS watch_scores (
      id TEXT PRIMARY KEY,
      round_id TEXT,
      player_id TEXT NOT NULL,
      hole_number INTEGER NOT NULL,
      gross_score INTEGER,
      putts INTEGER,
      penalties INTEGER,
      fairway_hit INTEGER,
      gir INTEGER,
      notes TEXT,
      entered_at TEXT NOT NULL,
      sync_status TEXT DEFAULT 'local',
      version INTEGER DEFAULT 1,
      updated_at TEXT NOT NULL
    )
  ''';

  /// Create watch_rounds table.
  static const String createRoundsTable = '''
    CREATE TABLE IF NOT EXISTS watch_rounds (
      id TEXT PRIMARY KEY,
      round_id TEXT,
      course_id INTEGER NOT NULL,
      course_name TEXT NOT NULL,
      tee_set_id TEXT NOT NULL,
      current_hole INTEGER NOT NULL DEFAULT 1,
      current_par INTEGER NOT NULL,
      total_holes INTEGER NOT NULL DEFAULT 18,
      status TEXT NOT NULL DEFAULT 'active',
      gps_quality TEXT DEFAULT 'unknown',
      gps_accuracy_meters REAL DEFAULT 0,
      has_gps_fix INTEGER DEFAULT 0,
      scores_json TEXT,
      started_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      ended_at TEXT,
      package_version TEXT NOT NULL,
      sync_status TEXT DEFAULT 'local'
    )
  ''';

  /// Create watch_sync_queue table.
  static const String createSyncQueueTable = '''
    CREATE TABLE IF NOT EXISTS watch_sync_queue (
      id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      attempts INTEGER DEFAULT 0,
      last_attempt_at TEXT,
      status TEXT DEFAULT 'pending',
      error_message TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  /// Create watch_package_info table.
  static const String createPackageInfoTable = '''
    CREATE TABLE IF NOT EXISTS watch_package_info (
      course_id INTEGER PRIMARY KEY,
      package_id TEXT NOT NULL,
      version TEXT NOT NULL,
      checksum TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      downloaded_at TEXT NOT NULL,
      is_active INTEGER DEFAULT 1
    )
  ''';

  /// Index for querying pending sync items.
  static const String createSyncQueuePendingIndex = '''
    CREATE INDEX IF NOT EXISTS idx_watch_sync_queue_status
    ON watch_sync_queue(status, created_at)
  ''';

  /// Index for querying scores by round and player.
  static const String createScoresRoundPlayerIndex = '''
    CREATE INDEX IF NOT EXISTS idx_watch_scores_round_player
    ON watch_scores(player_id, hole_number)
  ''';

  /// All schema creation statements in order.
  static const List<String> allStatements = [
    createScoresTable,
    createRoundsTable,
    createSyncQueueTable,
    createPackageInfoTable,
    createSyncQueuePendingIndex,
    createScoresRoundPlayerIndex,
  ];

  /// Drop all watch tables (for testing/reset).
  static const List<String> dropStatements = [
    'DROP TABLE IF EXISTS watch_scores',
    'DROP TABLE IF EXISTS watch_rounds',
    'DROP TABLE IF EXISTS watch_sync_queue',
    'DROP TABLE IF EXISTS watch_package_info',
  ];
}
