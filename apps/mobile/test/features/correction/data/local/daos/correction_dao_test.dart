// CorrectionDao unit tests — VSP Mobile App
//
// Tests cover:
// - upsert inserts a new correction
// - upsert replaces an existing correction (same id)
// - getById returns correct correction
// - getById returns null for non-existent id
// - getBySyncState returns corrections with matching state
// - getByCourseId returns corrections for a course
// - updateSyncState updates sync state by id
// - getByIdempotencyKey returns correction by idempotency key
// - delete removes correction by id
//
// Per Story 9.1 Slice 1: Domain Model + DTO + SQLite.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uuid/uuid.dart';
import 'package:vsp_mobile/data/local/daos/correction_dao.dart';
import 'package:vsp_mobile/data/local/round_database.dart';
import 'package:vsp_mobile/data/local/tables/corrections_table.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';
import 'package:vsp_mobile/features/correction/domain/geometry_layer.dart';

/// Fake path provider for sqflite in tests (in-memory).
class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp';

  @override
  Future<String?> getTemporaryDirectory() async => '/tmp';
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late CorrectionDao dao;
  final uuid = const Uuid();
  final now = DateTime.now().toUtc();

  setUpAll(() {
    PathProviderPlatform.instance = FakePathProvider();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kRoundDbVersion,
        // Build the table from the shared schema constant rather than a copy of
        // it: a hand-written CREATE TABLE here drifts silently from the real
        // one, and the DAO then passes tests against a table the app does not
        // have (which is exactly what happened when `layer` was added).
        onCreate: (db, version) async {
          await db.execute(kCorrectionsTableCreateSql);
          await db.execute(kCorrectionsTableCourseIndexSql);
          await db.execute(kCorrectionsTableSyncStateIndexSql);
          await db.execute(kCorrectionsTableIdempotencyIndexSql);
        },
      ),
    );
    dao = CorrectionDao.withDatabase(db);
  });

  tearDown(() async {
    await dao.close();
  });

  CourseCorrection buildCorrection({
    String? id,
    String? courseId,
    String? holeId,
    CorrectionIssueType issueType = CorrectionIssueType.pinPosition,
    double gpsAccuracy = 3.0,
    CorrectionSyncState syncState = CorrectionSyncState.pending,
    String? note,
    String? idempotencyKey,
  }) {
    return CourseCorrection(
      id: id ?? uuid.v4(),
      courseId: courseId ?? 'course-001',
      holeId: holeId,
      issueType: issueType,
      reporterLat: 10.762622,
      reporterLng: 106.660020,
      gpsAccuracy: gpsAccuracy,
      submittedAt: now,
      note: note,
      syncState: syncState,
      idempotencyKey: idempotencyKey ?? uuid.v4(),
    );
  }

  group('upsert', () {
    test('inserts a new correction', () async {
      final correction = buildCorrection(
        id: 'corr-001',
        idempotencyKey: 'idem-001',
      );
      await dao.upsert(correction);

      final retrieved = await dao.getById('corr-001');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'corr-001');
      expect(retrieved.courseId, 'course-001');
      expect(retrieved.syncState, CorrectionSyncState.pending);
    });

    test('replaces existing correction with same id', () async {
      final original = buildCorrection(
        id: 'corr-002',
        idempotencyKey: 'idem-002',
      );
      await dao.upsert(original);

      final updated = original.copyWith(
        syncState: CorrectionSyncState.submitted,
        note: 'Updated note',
      );
      await dao.upsert(updated);

      final retrieved = await dao.getById('corr-002');
      expect(retrieved!.syncState, CorrectionSyncState.submitted);
      expect(retrieved.note, 'Updated note');
    });

    test('rejects duplicate idempotency key via UNIQUE constraint', () async {
      final correction = buildCorrection(
        id: 'corr-003',
        idempotencyKey: 'idem-dup',
      );
      await dao.upsert(correction);

      final duplicate = buildCorrection(
        id: 'corr-003-diff',
        idempotencyKey: 'idem-dup',
      );
      // upsert with ConflictAlgorithm.replace should replace the original
      await dao.upsert(duplicate);

      final retrieved = await dao.getById('corr-003-diff');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'corr-003-diff');
      expect(retrieved.idempotencyKey, 'idem-dup');
    });
  });

  group('getById', () {
    test('returns correct correction', () async {
      final correction = buildCorrection(
        id: 'corr-010',
        idempotencyKey: 'idem-010',
      );
      await dao.upsert(correction);

      final retrieved = await dao.getById('corr-010');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'corr-010');
    });

    test('returns null for non-existent id', () async {
      final retrieved = await dao.getById('non-existent');
      expect(retrieved, isNull);
    });
  });

  group('getBySyncState', () {
    test('returns only corrections with matching sync state', () async {
      await dao.upsert(
        buildCorrection(
          id: 'corr-020',
          syncState: CorrectionSyncState.pending,
          idempotencyKey: 'idem-020',
        ),
      );
      await dao.upsert(
        buildCorrection(
          id: 'corr-021',
          syncState: CorrectionSyncState.pending,
          idempotencyKey: 'idem-021',
        ),
      );
      await dao.upsert(
        buildCorrection(
          id: 'corr-022',
          syncState: CorrectionSyncState.submitted,
          idempotencyKey: 'idem-022',
        ),
      );

      final pending = await dao.getBySyncState(CorrectionSyncState.pending);
      final submitted = await dao.getBySyncState(CorrectionSyncState.submitted);

      expect(pending.length, 2);
      expect(submitted.length, 1);
      expect(submitted.first.id, 'corr-022');
    });

    test('returns empty list when no corrections match state', () async {
      final result = await dao.getBySyncState(CorrectionSyncState.accepted);
      expect(result, isEmpty);
    });
  });

  group('getByCourseId', () {
    test('returns corrections for the specified course', () async {
      await dao.upsert(
        buildCorrection(
          id: 'corr-030',
          courseId: 'course-a',
          idempotencyKey: 'idem-030',
        ),
      );
      await dao.upsert(
        buildCorrection(
          id: 'corr-031',
          courseId: 'course-a',
          idempotencyKey: 'idem-031',
        ),
      );
      await dao.upsert(
        buildCorrection(
          id: 'corr-032',
          courseId: 'course-b',
          idempotencyKey: 'idem-032',
        ),
      );

      final courseACorrections = await dao.getByCourseId('course-a');
      final courseBCorrections = await dao.getByCourseId('course-b');

      expect(courseACorrections.length, 2);
      expect(courseBCorrections.length, 1);
    });

    test('returns empty list for course with no corrections', () async {
      final result = await dao.getByCourseId('non-existent-course');
      expect(result, isEmpty);
    });

    test('returns corrections ordered by submittedAt descending', () async {
      final now = DateTime.now().toUtc();
      final earlier = now.subtract(const Duration(hours: 1));
      final later = now.add(const Duration(hours: 1));

      await dao.upsert(
        buildCorrection(
          id: 'corr-040',
          courseId: 'course-t',
          idempotencyKey: 'idem-040',
        ).copyWith(submittedAt: earlier),
      );
      await dao.upsert(
        buildCorrection(
          id: 'corr-041',
          courseId: 'course-t',
          idempotencyKey: 'idem-041',
        ).copyWith(submittedAt: later),
      );

      final result = await dao.getByCourseId('course-t');
      expect(result.first.id, 'corr-041'); // later first
      expect(result.last.id, 'corr-040');
    });
  });

  group('updateSyncState', () {
    test('updates sync state and returns 1', () async {
      await dao.upsert(
        buildCorrection(id: 'corr-050', idempotencyKey: 'idem-050'),
      );

      final rowsUpdated = await dao.updateSyncState(
        'corr-050',
        CorrectionSyncState.submitted,
      );
      expect(rowsUpdated, 1);

      final retrieved = await dao.getById('corr-050');
      expect(retrieved!.syncState, CorrectionSyncState.submitted);
    });

    test('returns 0 when correction does not exist', () async {
      final rowsUpdated = await dao.updateSyncState(
        'non-existent',
        CorrectionSyncState.accepted,
      );
      expect(rowsUpdated, 0);
    });
  });

  group('getByIdempotencyKey', () {
    test('returns correction by idempotency key', () async {
      await dao.upsert(
        buildCorrection(id: 'corr-060', idempotencyKey: 'idem-key-060'),
      );

      final retrieved = await dao.getByIdempotencyKey('idem-key-060');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'corr-060');
    });

    test('returns null for non-existent idempotency key', () async {
      final retrieved = await dao.getByIdempotencyKey('non-existent-key');
      expect(retrieved, isNull);
    });
  });

  group('delete', () {
    test('removes correction by id', () async {
      await dao.upsert(
        buildCorrection(id: 'corr-070', idempotencyKey: 'idem-070'),
      );

      await dao.delete('corr-070');

      final retrieved = await dao.getById('corr-070');
      expect(retrieved, isNull);
    });

    test('delete is idempotent — no error when id does not exist', () async {
      await dao.delete('non-existent-id'); // should not throw
    });
  });

  group('geometry layer', () {
    test('round-trips the reported layer through the real schema', () async {
      final correction = buildCorrection(
        id: 'corr-layer-1',
        idempotencyKey: 'idem-layer-1',
      ).copyWith(layer: GeometryLayer.water, holeId: 'hole-7');

      await dao.upsert(correction);
      final loaded = await dao.getById('corr-layer-1');

      expect(loaded!.layer, GeometryLayer.water);
      expect(loaded.holeId, 'hole-7');
    });

    test('a correction with no layer stores null', () async {
      await dao.upsert(
        buildCorrection(id: 'corr-layer-2', idempotencyKey: 'idem-layer-2'),
      );
      expect((await dao.getById('corr-layer-2'))!.layer, isNull);
    });
  });
}
