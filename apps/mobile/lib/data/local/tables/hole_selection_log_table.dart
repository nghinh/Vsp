// HoleSelectionLog Table — VSP Mobile App
//
// SQLite table definition for ManualHoleSelection entities.
// Append-only audit log for manual hole selections and overrides.
//
// Story 6.2 — Wave D: Manual Override & Audit

/// SQL for creating the hole_selection_log table.
const String kHoleSelectionLogTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS hole_selection_log (
    id TEXT PRIMARY KEY,
    round_id TEXT NOT NULL,
    detected_hole_id TEXT,
    selected_hole_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    confidence_before REAL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    accuracy_meters REAL,
    heading REAL,
    location_source TEXT NOT NULL,
    location_timestamp TEXT NOT NULL,
    selected_at TEXT NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'local'
  )
''';

/// SQL for creating an index on round_id for round-scoped queries.
const String kHoleSelectionLogTableRoundIdIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_hole_selection_log_round_id ON hole_selection_log (round_id)
''';

/// SQL for creating an index on sync_status for sync worker queries.
const String kHoleSelectionLogTableSyncStatusIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_hole_selection_log_sync_status ON hole_selection_log (sync_status)
''';

/// Table name constant.
const String kHoleSelectionLogTableName = 'hole_selection_log';
