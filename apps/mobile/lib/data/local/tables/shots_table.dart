// Shots Table — VSP Mobile App
//
// SQLite table definition for Shot entities.
// Used by ShotDao for CRUD operations.
//
// Story 10.3 — Slice 1: Domain + Persistence

/// SQL for creating the shots table.
const String kShotsTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS shots (
    id TEXT PRIMARY KEY,
    round_id TEXT NOT NULL,
    flight_id TEXT NOT NULL,
    player_id TEXT NOT NULL,
    hole_number INTEGER NOT NULL,
    shot_number INTEGER NOT NULL,
    club_id TEXT,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    start_location TEXT,
    end_location TEXT,
    lie TEXT,
    distance_yards REAL,
    distance_meters REAL,
    conditions TEXT,
    result TEXT,
    is_penalty INTEGER NOT NULL DEFAULT 0,
    is_provisional INTEGER NOT NULL DEFAULT 0,
    is_mulligan INTEGER NOT NULL DEFAULT 0,
    merged_into_shot_id TEXT,
    source TEXT NOT NULL DEFAULT 'manual',
    confidence REAL,
    sync_status TEXT NOT NULL DEFAULT 'pending',
    idempotency_key TEXT NOT NULL,
    server_sync_status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''';

/// SQL for creating an index on round_id for round-based lookups.
const String kShotsTableRoundIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_shots_round ON shots (round_id)
''';

/// SQL for creating an index on round_id + player_id for player-based lookups.
const String kShotsTableRoundPlayerIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_shots_round_player ON shots (round_id, player_id)
''';

/// SQL for creating an index on sync_status for pending-shot queries.
const String kShotsTableSyncStatusIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_shots_sync_status ON shots (sync_status)
''';

/// Table name constant.
const String kShotsTableName = 'shots';
