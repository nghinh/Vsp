// Weather Snapshots Table — VSP Mobile App
//
// Story 7.1 Wave 2: SQLite Persistence
// Per slice plan §2.4 — one snapshot per course_id (UNIQUE constraint).
//
// Schema mirrors the WeatherSnapshotDto from the backend API.
// Caches the full JSON so schema changes don't require migrations.

/// SQL for creating the weather_snapshots table.
const String kWeatherSnapshotsTableCreateSql = '''
  CREATE TABLE IF NOT EXISTS weather_snapshots (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL,
    captured_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    is_forecast INTEGER NOT NULL DEFAULT 0,
    provider TEXT NOT NULL,
    source_name TEXT NOT NULL,
    source_timestamp TEXT NOT NULL,
    json_data TEXT NOT NULL,
    UNIQUE(course_id)
  )
''';

/// SQL for creating an index on course_id for fast lookups.
const String kWeatherSnapshotsCourseIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_weather_snapshots_course ON weather_snapshots (course_id)
''';

/// SQL for creating an index on captured_at for staleness queries.
const String kWeatherSnapshotsCapturedAtIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_weather_snapshots_captured ON weather_snapshots (captured_at)
''';

/// Table name constant.
const String kWeatherSnapshotsTableName = 'weather_snapshots';
