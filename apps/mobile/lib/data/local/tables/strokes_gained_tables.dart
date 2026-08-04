// Strokes Gained Tables — VSP Mobile App
//
// SQLite table definitions for Strokes Gained entities.
// Used by StrokesGainedDao for CRUD operations.
//
// Story 11.3 — Slice 2: Repository + OpenAPI

/// SQL for creating the strokes_gained_summaries table.
const String kStrokesGainedSummariesTableCreateSql = '''
  CREATE TABLE strokes_gained_summaries (
    id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    round_id TEXT,
    date_range_start TEXT,
    date_range_end TEXT,
    overall_sg REAL NOT NULL DEFAULT 0.0,
    category_breakdown_json TEXT NOT NULL,
    limitations_json TEXT NOT NULL,
    confidence REAL NOT NULL DEFAULT 0.0,
    last_calculated_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''';

/// SQL for creating an index on player_id for player-based lookups.
const String kStrokesGainedSummariesPlayerIndexSql = '''
  CREATE INDEX idx_sg_summaries_player ON strokes_gained_summaries (player_id)
''';

/// SQL for creating an index on player_id + round_id.
const String kStrokesGainedSummariesRoundIndexSql = '''
  CREATE INDEX idx_sg_summaries_round ON strokes_gained_summaries (player_id, round_id)
''';

/// SQL for creating the sg_benchmarks table.
const String kSgBenchmarksTableCreateSql = '''
  CREATE TABLE sg_benchmarks (
    id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    benchmark_type TEXT NOT NULL,
    category TEXT NOT NULL,
    baseline_strokes REAL NOT NULL,
    sample_count INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL,
    UNIQUE(player_id, benchmark_type, category)
  )
''';

/// SQL for creating an index on player_id + benchmark_type.
const String kSgBenchmarksPlayerTypeIndexSql = '''
  CREATE INDEX idx_sg_benchmarks_player_type ON sg_benchmarks (player_id, benchmark_type)
''';

/// Table name constants.
const String kStrokesGainedSummariesTableName = 'strokes_gained_summaries';
const String kSgBenchmarksTableName = 'sg_benchmarks';
