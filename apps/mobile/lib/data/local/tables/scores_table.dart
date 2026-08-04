// Scores Table — VSP Mobile App
//
// SQLite table definition for Score entities.
// Used by ScoreDao for CRUD operations.
// UNIQUE constraint enforces exactly one Score per (flightId, holeId, playerId).
//
// Story 5.3 — Slice 2: Score SQLite Persistence

/// SQL for creating the scores table.
const String kScoresTableCreateSql = '''
  CREATE TABLE scores (
    id TEXT PRIMARY KEY,
    flight_id TEXT NOT NULL,
    hole_id TEXT NOT NULL,
    player_id TEXT NOT NULL,
    gross_score INTEGER,
    putts INTEGER,
    penalties INTEGER,
    fairway_hit INTEGER,
    gir INTEGER,
    bunker INTEGER,
    notes TEXT,
    entered_at TEXT,
    sync_status TEXT NOT NULL DEFAULT 'local',
    version INTEGER NOT NULL DEFAULT 1,
    updated_at TEXT NOT NULL,
    UNIQUE(flight_id, hole_id, player_id)
  )
''';

/// SQL for creating a compound index on flight_id + hole_id for hole-based lookups.
const String kScoresTableFlightHoleIndexSql = '''
  CREATE INDEX idx_scores_flight_hole ON scores (flight_id, hole_id)
''';

/// SQL for creating an index on flight_id + player_id for player-based lookups.
const String kScoresTableFlightPlayerIndexSql = '''
  CREATE INDEX idx_scores_flight_player ON scores (flight_id, player_id)
''';

/// Table name constant.
const String kScoresTableName = 'scores';
