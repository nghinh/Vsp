// Telemetry Tables — VSP Mobile App
//
// SQLite table definitions for GPS, battery, and map latency telemetry.
// Used by TelemetryDao for CRUD operations.
//
// Story 6.6 — Slice B: Telemetry Service Interface + Local Persistence

/// SQL for creating the telemetry table (unified GPS + battery + map latency).
/// Each row stores one telemetry event with a type discriminator.
const String kTelemetryTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS telemetry (
    id TEXT PRIMARY KEY,
    round_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    json_payload TEXT NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'local',
    version INTEGER NOT NULL DEFAULT 1,
    updated_at TEXT NOT NULL
  )
''';

/// SQL for creating an index on round_id for efficient round-based lookups.
const String kTelemetryTableRoundIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_telemetry_round_id ON telemetry (round_id)
''';

/// SQL for creating an index on event_type for efficient type-based filtering.
const String kTelemetryTableEventTypeIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_telemetry_event_type ON telemetry (event_type)
''';

/// SQL for creating an index on sync_status for efficient sync queue queries.
const String kTelemetryTableSyncStatusIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_telemetry_sync_status ON telemetry (sync_status)
''';

/// SQL for creating a compound index on round_id + event_type.
const String kTelemetryTableRoundTypeIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_telemetry_round_type ON telemetry (round_id, event_type)
''';

/// Table name constant.
const String kTelemetryTableName = 'telemetry';

/// Event type discriminator values stored in the event_type column.
class TelemetryEventTypes {
  TelemetryEventTypes._();

  static const String gps = 'gps';
  static const String battery = 'battery';
  static const String mapLatency = 'map_latency';
}

/// Sync status values for telemetry records.
class TelemetrySyncStatus {
  TelemetrySyncStatus._();

  static const String local = 'local';
  static const String synced = 'synced';
  static const String failed = 'failed';
}
