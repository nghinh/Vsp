// Round Database — VSP Mobile App
//
// Single source of truth for the shared `vsp_round.db` SQLite file.
//
// Several DAOs and stores persist into this ONE file: scores, corrections,
// hole-selection log, flights, weather snapshots, telemetry, strokes-gained
// summaries/benchmarks, and the round-sync queue. sqflite runs a database's
// `onCreate`/`onOpen` callbacks only for the FIRST caller that opens a given
// path, and returns a cached instance to every later caller without re-running
// those callbacks. If each DAO created only its own table, whichever DAO opened
// the file first would be the only one whose table exists — every other DAO
// would then hit "no such table: …" (this is exactly what broke score entry).
//
// To make ordering irrelevant, every DAO opens the file through
// [openRoundDatabase], whose [createRoundSchema] creates ALL tables together.
// All statements use `CREATE ... IF NOT EXISTS`, so running the schema on both
// `onCreate` and `onOpen` — and across pre-existing installs — is idempotent.

import 'package:sqflite/sqflite.dart';

import 'tables/corrections_table.dart';
import 'tables/flights_table.dart';
import 'tables/hole_selection_log_table.dart';
import 'tables/scores_table.dart';
import 'tables/strokes_gained_tables.dart';
import 'tables/telemetry_table.dart';
import 'tables/weather_snapshots_table.dart';

/// Shared file name for the round-scoped SQLite database.
const String kRoundDbName = 'vsp_round.db';

/// Schema version for [kRoundDbName].
///
/// Historically `RoundRepository` bumped this file to v2 (Story 12.1 added
/// tournament columns to `rounds`) while every other DAO still opened it at v1.
/// Because they all share ONE file, a v1 opener arriving after the v2 opener
/// triggered a spurious sqflite downgrade error. The shared opener pins the file
/// to v2 for everyone; [migrateRoundSchema] performs the v1→v2 column adds.
const int kRoundDbVersion = 2;

/// Round-sync queue table (owned historically by `RoundSyncStore`).
const String kRoundSyncQueueTableName = 'round_sync_queue';

const String kRoundSyncQueueTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS $kRoundSyncQueueTableName (
    idempotency_key TEXT PRIMARY KEY,
    operation TEXT NOT NULL,
    round_id TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    synced_at TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0
  )
''';

const String kRoundSyncQueuePendingIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_round_sync_pending
  ON $kRoundSyncQueueTableName (created_at)
  WHERE synced_at IS NULL
''';

/// Rounds table (owned historically by `RoundRepository`). Full v2 shape,
/// including the tournament columns added by Story 12.1.
const String kRoundsTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS rounds (
    id TEXT PRIMARY KEY,
    course_id INTEGER NOT NULL,
    course_name TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    package_version TEXT NOT NULL,
    tournament_policy_id TEXT,
    tournament_id TEXT,
    tournament_policy_version INTEGER,
    tournament_policy_json TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''';

const String kRoundsStatusIndexSql =
    'CREATE INDEX IF NOT EXISTS idx_rounds_status ON rounds (status)';

const String kRoundsTournamentPolicyIndexSql =
    'CREATE INDEX IF NOT EXISTS idx_rounds_tournament_policy ON rounds (tournament_policy_id)';

/// Players table (owned historically by `PlayerRepository`).
const String kPlayersTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS players (
    id TEXT PRIMARY KEY,
    round_id TEXT NOT NULL,
    name TEXT NOT NULL,
    handicap REAL,
    is_current_user INTEGER NOT NULL
  )
''';

const String kPlayersRoundIndexSql =
    'CREATE INDEX IF NOT EXISTS idx_players_round ON players (round_id)';

/// Hole-scores table (owned historically by `HoleScoreRepository`).
const String kHoleScoresTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS hole_scores (
    id TEXT PRIMARY KEY,
    round_id TEXT NOT NULL,
    hole_number INTEGER NOT NULL,
    par INTEGER NOT NULL,
    strokes INTEGER NOT NULL,
    putts INTEGER,
    penalties INTEGER,
    fairway_hit INTEGER,
    gir INTEGER,
    club_used TEXT,
    notes TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''';

const String kHoleScoresRoundIndexSql =
    'CREATE INDEX IF NOT EXISTS idx_hole_scores_round ON hole_scores (round_id)';

const String kHoleScoresHoleIndexSql =
    'CREATE INDEX IF NOT EXISTS idx_hole_scores_hole ON hole_scores (round_id, hole_number)';

/// Creates every table owned by the shared `vsp_round.db` file.
///
/// Idempotent: safe to run on `onCreate`, on `onOpen`, and repeatedly.
Future<void> createRoundSchema(Database db, [int? version]) async {
  // scores
  await db.execute(kScoresTableCreateSql);
  await db.execute(kScoresTableFlightHoleIndexSql);
  await db.execute(kScoresTableFlightPlayerIndexSql);
  // corrections
  await db.execute(kCorrectionsTableCreateSql);
  await db.execute(kCorrectionsTableCourseIndexSql);
  await db.execute(kCorrectionsTableSyncStateIndexSql);
  await db.execute(kCorrectionsTableIdempotencyIndexSql);
  // hole-selection log
  await db.execute(kHoleSelectionLogTableCreateSql);
  await db.execute(kHoleSelectionLogTableRoundIdIndexSql);
  await db.execute(kHoleSelectionLogTableSyncStatusIndexSql);
  // flights
  await db.execute(kFlightsTableCreateSql);
  await db.execute(kFlightsTableRoundIndexSql);
  // weather snapshots
  await db.execute(kWeatherSnapshotsTableCreateSql);
  await db.execute(kWeatherSnapshotsCourseIndexSql);
  await db.execute(kWeatherSnapshotsCapturedAtIndexSql);
  // telemetry
  await db.execute(kTelemetryTableCreateSql);
  await db.execute(kTelemetryTableRoundIndexSql);
  await db.execute(kTelemetryTableEventTypeIndexSql);
  await db.execute(kTelemetryTableSyncStatusIndexSql);
  await db.execute(kTelemetryTableRoundTypeIndexSql);
  // strokes-gained
  await db.execute(kStrokesGainedSummariesTableCreateSql);
  await db.execute(kStrokesGainedSummariesPlayerIndexSql);
  await db.execute(kStrokesGainedSummariesRoundIndexSql);
  await db.execute(kSgBenchmarksTableCreateSql);
  await db.execute(kSgBenchmarksPlayerTypeIndexSql);
  // round-sync queue
  await db.execute(kRoundSyncQueueTableCreateSql);
  await db.execute(kRoundSyncQueuePendingIndexSql);
  // rounds
  await db.execute(kRoundsTableCreateSql);
  await db.execute(kRoundsStatusIndexSql);
  await db.execute(kRoundsTournamentPolicyIndexSql);
  // players
  await db.execute(kPlayersTableCreateSql);
  await db.execute(kPlayersRoundIndexSql);
  // hole scores
  await db.execute(kHoleScoresTableCreateSql);
  await db.execute(kHoleScoresRoundIndexSql);
  await db.execute(kHoleScoresHoleIndexSql);
}

/// Migrates an existing `vsp_round.db` from [oldVersion] up to [kRoundDbVersion].
///
/// First ensures every table exists (older installs may be missing tables that
/// were never created due to the historical shared-file bug), then applies the
/// per-version column additions. Column adds are guarded so re-running is safe.
Future<void> migrateRoundSchema(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  await createRoundSchema(db);
  if (oldVersion < 2) {
    // Story 12.1: tournament columns on `rounds`.
    await _addColumnIfMissing(db, 'rounds', 'tournament_id', 'TEXT');
    await _addColumnIfMissing(
      db,
      'rounds',
      'tournament_policy_version',
      'INTEGER',
    );
    await _addColumnIfMissing(db, 'rounds', 'tournament_policy_json', 'TEXT');
  }
}

Future<void> _addColumnIfMissing(
  Database db,
  String table,
  String column,
  String type,
) async {
  final cols = await db.rawQuery('PRAGMA table_info($table)');
  final exists = cols.any((c) => c['name'] == column);
  if (!exists) {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }
}

/// Opens the shared round database, guaranteeing the full schema exists.
///
/// Every DAO/store persisting into `vsp_round.db` MUST open it through this so
/// the complete schema is created regardless of which one opens the file first.
Future<Database> openRoundDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = '$dbPath/$kRoundDbName';
  return openDatabase(
    path,
    version: kRoundDbVersion,
    onCreate: createRoundSchema,
    onUpgrade: migrateRoundSchema,
    onOpen: createRoundSchema,
  );
}
