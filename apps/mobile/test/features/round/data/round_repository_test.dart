// RoundRepository unit tests — VSP Mobile App
//
// Tests cover:
// - createRound and getRound round-trip
// - updateRound persists changes
// - getActiveRound returns in-progress round
// - getRoundsByCourse filters correctly
// - transactional wraps multi-table writes

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:uuid/uuid.dart';
import 'package:vsp_mobile/data/repositories/round_repository.dart';
import 'package:vsp_mobile/domain/models/round.dart';

/// Fake path provider for sqflite in tests (in-memory).
class FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp';

  @override
  Future<String?> getTemporaryDirectory() async => '/tmp';
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late RoundRepository repo;

  setUpAll(() {
    PathProviderPlatform.instance = FakePathProvider();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE rounds (
            id TEXT PRIMARY KEY,
            course_id INTEGER NOT NULL,
            back_nine_course_id INTEGER,
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
        ''');
          await db.execute('''
          CREATE INDEX idx_rounds_status ON rounds (status)
        ''');
        },
      ),
    );
    repo = TestableRoundRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('RoundRepository', () {
    group('createRound and getRound', () {
      test('inserts round and retrieves it by id', () async {
        final now = DateTime.now();
        final round = Round(
          id: const Uuid().v4(),
          courseId: 1,
          courseName: 'Pinehurst No. 2',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1.0.0',
          createdAt: now,
          updatedAt: now,
        );

        await repo.createRound(round);
        final retrieved = await repo.getRound(round.id);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, round.id);
        expect(retrieved.courseId, round.courseId);
        expect(retrieved.courseName, round.courseName);
        expect(retrieved.status, RoundStatus.inProgress);
        expect(retrieved.packageVersion, round.packageVersion);
      });

      test('getRound returns null for unknown id', () async {
        final result = await repo.getRound('non-existent-id');
        expect(result, isNull);
      });
    });

    group('updateRound', () {
      test('updateRound persists changed fields', () async {
        final now = DateTime.now();
        final round = Round(
          id: const Uuid().v4(),
          courseId: 2,
          courseName: 'Augusta National',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1.0.0',
          createdAt: now,
          updatedAt: now,
        );

        await repo.createRound(round);

        final updated = round.copyWith(
          status: RoundStatus.completed,
          endedAt: DateTime.now(),
        );
        await repo.updateRound(updated);

        final retrieved = await repo.getRound(round.id);
        expect(retrieved!.status, RoundStatus.completed);
        expect(retrieved.endedAt, isNotNull);
      });
    });

    group('getActiveRound', () {
      test('returns in-progress round ordered by started_at DESC', () async {
        final now = DateTime.now();
        final r1 = Round(
          id: const Uuid().v4(),
          courseId: 1,
          courseName: 'Course A',
          status: RoundStatus.completed,
          startedAt: now.subtract(const Duration(hours: 2)),
          endedAt: now.subtract(const Duration(hours: 1)),
          packageVersion: 'v1',
          createdAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now.subtract(const Duration(hours: 2)),
        );
        final r2 = Round(
          id: const Uuid().v4(),
          courseId: 2,
          courseName: 'Course B',
          status: RoundStatus.inProgress,
          startedAt: now.subtract(const Duration(minutes: 30)),
          endedAt: null,
          packageVersion: 'v1',
          createdAt: now.subtract(const Duration(minutes: 30)),
          updatedAt: now.subtract(const Duration(minutes: 30)),
        );

        await repo.createRound(r1);
        await repo.createRound(r2);

        final active = await repo.getActiveRound();

        expect(active, isNotNull);
        expect(active!.id, r2.id);
        expect(active.status, RoundStatus.inProgress);
      });

      test('returns null when no in-progress round exists', () async {
        final now = DateTime.now();
        final r = Round(
          id: const Uuid().v4(),
          courseId: 1,
          courseName: 'Completed Course',
          status: RoundStatus.completed,
          startedAt: now.subtract(const Duration(hours: 2)),
          endedAt: now.subtract(const Duration(hours: 1)),
          packageVersion: 'v1',
          createdAt: now.subtract(const Duration(hours: 2)),
          updatedAt: now.subtract(const Duration(hours: 2)),
        );
        await repo.createRound(r);

        final active = await repo.getActiveRound();
        expect(active, isNull);
      });
    });

    group('getRoundsByCourse', () {
      test('returns all rounds for a given courseId', () async {
        final now = DateTime.now();
        final r1 = Round(
          id: const Uuid().v4(),
          courseId: 5,
          courseName: 'Bethpage Black',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1',
          createdAt: now,
          updatedAt: now,
        );
        final r2 = Round(
          id: const Uuid().v4(),
          courseId: 5,
          courseName: 'Bethpage Black',
          status: RoundStatus.completed,
          startedAt: now.subtract(const Duration(days: 1)),
          endedAt: now.subtract(const Duration(days: 1)),
          packageVersion: 'v1',
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(days: 1)),
        );
        final r3 = Round(
          id: const Uuid().v4(),
          courseId: 6,
          courseName: 'Pebble Beach',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1',
          createdAt: now,
          updatedAt: now,
        );

        await repo.createRound(r1);
        await repo.createRound(r2);
        await repo.createRound(r3);

        final forCourse5 = await repo.getRoundsByCourse(5);
        expect(forCourse5.length, 2);
        expect(forCourse5.map((r) => r.id), containsAll([r1.id, r2.id]));

        final forCourse6 = await repo.getRoundsByCourse(6);
        expect(forCourse6.length, 1);
        expect(forCourse6.first.id, r3.id);
      });

      test('returns empty list for course with no rounds', () async {
        final result = await repo.getRoundsByCourse(9999);
        expect(result, isEmpty);
      });
    });

    group('transactional', () {
      test('transactional commits multiple round inserts atomically', () async {
        final now = DateTime.now();
        final r1 = Round(
          id: const Uuid().v4(),
          courseId: 10,
          courseName: 'Torrey Pines',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1',
          createdAt: now,
          updatedAt: now,
        );
        final r2 = Round(
          id: const Uuid().v4(),
          courseId: 11,
          courseName: 'Whistling Straits',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1',
          createdAt: now,
          updatedAt: now,
        );

        await repo.transactional((txn) async {
          await txn.insert('rounds', r1.toMap());
          await txn.insert('rounds', r2.toMap());
        });

        final retrieved1 = await repo.getRound(r1.id);
        final retrieved2 = await repo.getRound(r2.id);
        expect(retrieved1, isNotNull);
        expect(retrieved2, isNotNull);
      });

      test('transactional rolls back on failure', () async {
        final now = DateTime.now();
        final r1 = Round(
          id: const Uuid().v4(),
          courseId: 12,
          courseName: 'Royal Melbourne',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1',
          createdAt: now,
          updatedAt: now,
        );
        final r2WithDupId = Round(
          id: r1.id, // duplicate primary key
          courseId: 13,
          courseName: 'Royal Melbourne Duplicate',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1',
          createdAt: now,
          updatedAt: now,
        );

        try {
          await repo.transactional((txn) async {
            await txn.insert('rounds', r1.toMap());
            await txn.insert('rounds', r2WithDupId.toMap()); // fails: dup key
          });
        } catch (_) {
          // Expected — ConflictAlgorithm.fail throws on constraint violation
        }

        // r1 should not be persisted because the transaction rolled back
        final retrieved = await repo.getRound(r1.id);
        expect(retrieved, isNull);
      });
    });
  });
}

/// TestableRoundRepository — injects an open database directly,
/// bypassing path_provider for test isolation.
class TestableRoundRepository extends RoundRepository {
  final Database _testDb;

  TestableRoundRepository(this._testDb);

  @override
  Future<Database> get database async => _testDb;

  @override
  Future<void> close() async {
    // Don't close the test database — tearDown handles it
  }
}
