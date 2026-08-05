// Flights Table — VSP Mobile App
//
// SQLite table definition for Flight entities.
// Used by FlightDao for CRUD operations.
//
// Story 5.3 — Slice 2: Score SQLite Persistence

/// SQL for creating the flights table.
const String kFlightsTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS flights (
    id TEXT PRIMARY KEY,
    round_id TEXT NOT NULL,
    flight_index INTEGER NOT NULL,
    player_ids TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''';

/// SQL for creating an index on round_id for efficient round-based lookups.
const String kFlightsTableRoundIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_flights_round_id ON flights (round_id)
''';

/// Table name constant.
const String kFlightsTableName = 'flights';
