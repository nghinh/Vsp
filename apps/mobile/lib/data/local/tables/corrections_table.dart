// Corrections Table — VSP Mobile App
//
// SQLite table definition for CourseCorrection entities.
// Used by CorrectionDao for CRUD operations.
//
// Per Story 9.1 Slice 1: Domain Model + DTO + SQLite.

/// SQL for creating the corrections table.
const String kCorrectionsTableCreateSql = '''
  CREATE TABLE corrections (
    id TEXT PRIMARY KEY,
    course_id TEXT NOT NULL,
    hole_id TEXT,
    issue_type TEXT NOT NULL,
    reporter_lat REAL NOT NULL,
    reporter_lng REAL NOT NULL,
    gps_accuracy REAL NOT NULL,
    submitted_at TEXT NOT NULL,
    note TEXT,
    sync_state TEXT NOT NULL DEFAULT 'pending',
    idempotency_key TEXT NOT NULL
  )
''';

/// SQL for creating an index on course_id for course-scoped queries.
const String kCorrectionsTableCourseIndexSql = '''
  CREATE INDEX idx_corrections_course ON corrections (course_id)
''';

/// SQL for creating an index on sync_state for sync-queue polling.
const String kCorrectionsTableSyncStateIndexSql = '''
  CREATE INDEX idx_corrections_sync_state ON corrections (sync_state)
''';

/// SQL for creating an index on idempotency_key for deduplication checks.
const String kCorrectionsTableIdempotencyIndexSql = '''
  CREATE UNIQUE INDEX idx_corrections_idempotency ON corrections (idempotency_key)
''';

/// Table name constant.
const String kCorrectionsTableName = 'corrections';
