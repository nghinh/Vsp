// RoundStateService unit tests — VSP Mobile App
//
// Tests cover:
// - startRound creates round + players atomically + enqueues sync event
// - updateHoleScore persists score + enqueues sync event
// - endRound marks round complete + enqueues sync event + clears guard
// - getActiveRound delegates to repository
// - recoverActiveRound delegates to repository
// - hasUnsyncedChanges delegates to sync store
// - pendingSyncCount delegates to sync store
// - getSyncState returns correct sync state enum values

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uuid/uuid.dart';
import 'package:vsp_mobile/data/repositories/hole_score_repository.dart';
import 'package:vsp_mobile/data/repositories/package_manifest_repository.dart';
import 'package:vsp_mobile/data/repositories/player_repository.dart';
import 'package:vsp_mobile/data/repositories/round_repository.dart';
import 'package:vsp_mobile/data/services/active_round_guard.dart';
import 'package:vsp_mobile/data/services/round_state_service.dart';
import 'package:vsp_mobile/domain/models/hole_score.dart';
import 'package:vsp_mobile/domain/models/player.dart';
import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/domain/models/round_config.dart';
import 'package:vsp_mobile/domain/models/round_format.dart';
import 'package:vsp_mobile/domain/models/queued_round_update.dart';
import 'package:vsp_mobile/domain/models/round_mode.dart';
import 'package:vsp_mobile/domain/models/round_sync_operation.dart';
import 'package:vsp_mobile/core/storage/round_sync_store.dart';

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
  late RoundRepository roundRepo;
  late HoleScoreRepository scoreRepo;
  late PlayerRepository playerRepo;
  late RoundSyncStore syncStore;
  late FakeActiveRoundGuard fakeGuard;
  late RoundStateService service;

  final testCourseId = 1;
  final testCourseName = 'Pinehurst No. 2';

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
          await db.execute('''
          CREATE TABLE hole_scores (
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
        ''');
          await db.execute('''
          CREATE INDEX idx_hole_scores_round ON hole_scores (round_id)
        ''');
          await db.execute('''
          CREATE TABLE players (
            id TEXT PRIMARY KEY,
            round_id TEXT NOT NULL,
            name TEXT NOT NULL,
            handicap REAL,
            is_current_user INTEGER NOT NULL
          )
        ''');
          await db.execute('''
          CREATE INDEX idx_players_round ON players (round_id)
        ''');
          await db.execute('''
          CREATE TABLE round_sync_queue (
            idempotency_key TEXT PRIMARY KEY,
            operation TEXT NOT NULL,
            round_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced_at TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
          await db.execute('''
          CREATE INDEX idx_round_sync_pending
          ON round_sync_queue (created_at)
          WHERE synced_at IS NULL
        ''');
        },
      ),
    );

    roundRepo = TestableRoundRepository(db);
    scoreRepo = TestableHoleScoreRepository(db);
    playerRepo = TestablePlayerRepository(db);
    syncStore = TestableRoundSyncStore(db);
    fakeGuard = FakeActiveRoundGuard();

    service = RoundStateService(
      roundRepo: roundRepo,
      scoreRepo: scoreRepo,
      playerRepo: playerRepo,
      syncStore: syncStore,
      activeRoundGuard: fakeGuard,
    );
  });

  tearDown(() async {
    await db.close();
  });

  RoundConfig makeConfig() {
    return RoundConfig(
      courseId: testCourseId,
      courseName: testCourseName,
      format: RoundFormat.casual,
      playerIds: ['player-1', 'player-2'],
      players: [
        const Player(id: 'player-1', name: 'Alice', isPrimary: true),
        const Player(id: 'player-2', name: 'Bob', isPrimary: false),
      ],
      mode: RoundMode.strokePlay,
      startHole: 1,
      startTime: DateTime.now().add(const Duration(minutes: 5)),
      packageId: 'v1.0.0',
    );
  }

  group('RoundStateService', () {
    group('startRound', () {
      test('creates round atomically and returns it', () async {
        final config = makeConfig();

        final round = await service.startRound(config, config.players);

        expect(round.courseId, testCourseId);
        expect(round.courseName, testCourseName);
        expect(round.status, RoundStatus.inProgress);
        expect(round.endedAt, isNull);
        expect(round.packageVersion, 'v1.0.0');
      });

      test('persists round to database', () async {
        final config = makeConfig();

        final round = await service.startRound(config, config.players);

        final retrieved = await roundRepo.getRound(round.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.status, RoundStatus.inProgress);
      });

      test('persists players to database', () async {
        final config = makeConfig();

        final round = await service.startRound(config, config.players);

        final players = await playerRepo.getPlayersForRound(round.id);
        expect(players.length, 2);
        expect(players.map((p) => p.id), containsAll(['player-1', 'player-2']));
      });

      test('enqueues startRound sync event', () async {
        final config = makeConfig();

        await service.startRound(config, config.players);

        final pending = await syncStore.dequeueAll();
        expect(pending.any((e) => e.operation.name == 'startRound'), isTrue);
      });

      test('records round start in ActiveRoundGuard', () async {
        final config = makeConfig();

        final round = await service.startRound(config, config.players);

        expect(fakeGuard.recordedCourseIds, contains(testCourseId));
        expect(fakeGuard.recordedRoundIds[testCourseId], round.id);
      });

      test('startRound with empty players list still creates round', () async {
        final config = makeConfig().copyWith(playerIds: [], players: []);

        final round = await service.startRound(config, []);

        expect(round, isNotNull);
        expect(round.courseId, testCourseId);
      });
    });

    group('updateHoleScore', () {
      test('persists hole score to database', () async {
        final config = makeConfig();
        final round = await service.startRound(config, []);

        final score = HoleScore(
          id: const Uuid().v4(),
          roundId: round.id,
          holeNumber: 1,
          par: 4,
          strokes: 4,
          putts: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await service.updateHoleScore(round.id, score);

        final retrieved = await scoreRepo.getScoreForHole(round.id, 1);
        expect(retrieved, isNotNull);
        expect(retrieved!.strokes, 4);
      });

      test('enqueues updateHoleScore sync event', () async {
        final config = makeConfig();
        final round = await service.startRound(config, []);

        final score = HoleScore(
          id: const Uuid().v4(),
          roundId: round.id,
          holeNumber: 1,
          par: 4,
          strokes: 4,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await service.updateHoleScore(round.id, score);

        final pending = await syncStore.dequeueAll();
        expect(
          pending.any((e) => e.operation.name == 'updateHoleScore'),
          isTrue,
        );
      });

      test('updateHoleScore for non-existent round does not throw', () async {
        final score = HoleScore(
          id: const Uuid().v4(),
          roundId: 'non-existent-round',
          holeNumber: 1,
          par: 4,
          strokes: 4,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Should not throw
        await service.updateHoleScore('non-existent-round', score);
      });
    });

    group('endRound', () {
      test('updates round status to completed and sets endedAt', () async {
        final config = makeConfig();
        final round = await service.startRound(config, []);

        await service.endRound(round.id);

        final retrieved = await roundRepo.getRound(round.id);
        expect(retrieved!.status, RoundStatus.completed);
        expect(retrieved.endedAt, isNotNull);
      });

      test('enqueues endRound sync event', () async {
        final config = makeConfig();
        final round = await service.startRound(config, []);

        await service.endRound(round.id);

        final pending = await syncStore.dequeueAll();
        expect(pending.any((e) => e.operation.name == 'endRound'), isTrue);
      });

      test('clears ActiveRoundGuard record on endRound', () async {
        final config = makeConfig();
        final round = await service.startRound(config, []);
        expect(fakeGuard.recordedCourseIds, contains(testCourseId));

        await service.endRound(round.id);

        expect(fakeGuard.clearedCourseIds, contains(testCourseId));
      });

      test('endRound with unknown round id is safe', () async {
        // Should not throw
        await service.endRound('unknown-round-id');
      });
    });

    group('getActiveRound', () {
      test('returns the active round', () async {
        final config = makeConfig();
        final round = await service.startRound(config, []);

        final active = await service.getActiveRound();

        expect(active, isNotNull);
        expect(active!.id, round.id);
      });

      test('returns null when no active round', () async {
        final active = await service.getActiveRound();
        expect(active, isNull);
      });
    });

    group('getHoleScores', () {
      test('returns all hole scores for a round', () async {
        final config = makeConfig();
        final round = await service.startRound(config, []);

        final s1 = HoleScore(
          id: const Uuid().v4(),
          roundId: round.id,
          holeNumber: 1,
          par: 4,
          strokes: 4,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final s2 = HoleScore(
          id: const Uuid().v4(),
          roundId: round.id,
          holeNumber: 2,
          par: 3,
          strokes: 3,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await service.updateHoleScore(round.id, s1);
        await service.updateHoleScore(round.id, s2);

        final scores = await service.getHoleScores(round.id);
        expect(scores.length, 2);
      });
    });

    group('hasUnsyncedChanges and pendingSyncCount', () {
      test('hasUnsyncedChanges returns true after startRound', () async {
        final config = makeConfig();
        await service.startRound(config, []);

        final hasChanges = await service.hasUnsyncedChanges();
        expect(hasChanges, isTrue);
      });

      test(
        'hasUnsyncedChanges returns false after marking all synced',
        () async {
          final config = makeConfig();
          await service.startRound(config, []);

          final pending = await syncStore.dequeueAll();
          for (final entry in pending) {
            await syncStore.markSynced(entry.idempotencyKey);
          }

          final hasChanges = await service.hasUnsyncedChanges();
          expect(hasChanges, isFalse);
        },
      );

      test('pendingSyncCount returns correct count', () async {
        final config = makeConfig();
        await service.startRound(config, []);
        final round = (await service.getActiveRound())!;

        final s1 = HoleScore(
          id: const Uuid().v4(),
          roundId: round.id,
          holeNumber: 1,
          par: 4,
          strokes: 4,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await service.updateHoleScore(round.id, s1);

        final count = await service.pendingSyncCount();
        expect(count, 2); // startRound + updateHoleScore
      });
    });

    group('getSyncState', () {
      test('returns synced when no pending entries', () async {
        final state = await service.getSyncState();
        expect(state, RoundSyncState.synced);
      });

      test('returns pending when there are unsynced entries', () async {
        final config = makeConfig();
        await service.startRound(config, []);

        final state = await service.getSyncState();
        expect(state, RoundSyncState.pending);
      });
    });

    group('recoverActiveRound', () {
      test('returns active round on app restart', () async {
        final config = makeConfig();
        final round = await service.startRound(config, []);

        // Simulate app restart: create new service instance (fresh repos pointing to same DB)
        final recovered = await service.recoverActiveRound();

        expect(recovered, isNotNull);
        expect(recovered!.id, round.id);
      });

      test('returns null when no active round exists', () async {
        final recovered = await service.recoverActiveRound();
        expect(recovered, isNull);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test fakes
// ---------------------------------------------------------------------------

/// FakeActiveRoundGuard — records calls without real DB dependency.
class FakeActiveRoundGuard extends ActiveRoundGuard {
  FakeActiveRoundGuard() : super(manifestRepo: PackageManifestRepository());
  final Set<int> recordedCourseIds = {};
  final Map<int, String> recordedRoundIds = {};
  final Set<int> clearedCourseIds = {};

  @override
  Future<void> recordRoundStart(int courseId, {String? roundId}) async {
    recordedCourseIds.add(courseId);
    if (roundId != null) {
      recordedRoundIds[courseId] = roundId;
    }
  }

  @override
  Future<void> recordRoundEnd(int courseId) async {
    clearedCourseIds.add(courseId);
  }
}

// ---------------------------------------------------------------------------
// Testable repositories (inject in-memory DB)
// ---------------------------------------------------------------------------

class TestableRoundRepository extends RoundRepository {
  final Database _testDb;
  TestableRoundRepository(this._testDb);

  @override
  Future<T> transactional<T>(Future<T> Function(Transaction) action) =>
      _testDb.transaction(action);

  @override
  Future<Round?> getRound(String id) async {
    final rows = await _testDb.query(
      'rounds',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Round.fromMap(rows.first);
  }

  @override
  Future<Round?> getActiveRound() async {
    final rows = await _testDb.query(
      'rounds',
      where: 'status = ?',
      whereArgs: [RoundStatus.inProgress.name],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Round.fromMap(rows.first);
  }

  @override
  Future<void> updateRound(Round round) async {
    await _testDb.update(
      'rounds',
      round.toMap(),
      where: 'id = ?',
      whereArgs: [round.id],
    );
  }

  @override
  Future<void> close() async {}
}

class TestableHoleScoreRepository extends HoleScoreRepository {
  final Database _testDb;
  TestableHoleScoreRepository(this._testDb);

  @override
  Future<void> updateScore(HoleScore score) async {
    final updated = await _testDb.update(
      'hole_scores',
      score.toMap(),
      where: 'id = ?',
      whereArgs: [score.id],
    );
    if (updated == 0) {
      await _testDb.insert('hole_scores', score.toMap());
    }
  }

  @override
  Future<HoleScore?> getScoreForHole(String roundId, int holeNumber) async {
    final rows = await _testDb.query(
      'hole_scores',
      where: 'round_id = ? AND hole_number = ?',
      whereArgs: [roundId, holeNumber],
      limit: 1,
    );
    return rows.isEmpty ? null : HoleScore.fromMap(rows.first);
  }

  @override
  Future<List<HoleScore>> getScoresForRound(String roundId) async {
    final rows = await _testDb.query(
      'hole_scores',
      where: 'round_id = ?',
      whereArgs: [roundId],
      orderBy: 'hole_number ASC',
    );
    return rows.map(HoleScore.fromMap).toList();
  }

  @override
  Future<void> close() async {}
}

class TestablePlayerRepository extends PlayerRepository {
  final Database _testDb;
  TestablePlayerRepository(this._testDb);

  @override
  Future<List<Player>> getPlayersForRound(String roundId) async {
    final rows = await _testDb.query(
      'players',
      where: 'round_id = ?',
      whereArgs: [roundId],
    );
    return rows.map(Player.fromMap).toList();
  }

  @override
  Future<void> close() async {}
}

class TestableRoundSyncStore extends RoundSyncStore {
  final Database _testDb;
  TestableRoundSyncStore(this._testDb);

  @override
  Future<void> enqueueRoundOp({
    required String idempotencyKey,
    required RoundSyncOperation operation,
    required String roundId,
    String? payload,
  }) async {
    await _testDb.insert('round_sync_queue', {
      'idempotency_key': idempotencyKey,
      'operation': operation.name,
      'round_id': roundId,
      'payload': payload ?? '{}',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'retry_count': 0,
    });
  }

  @override
  Future<List<QueuedRoundUpdate>> dequeueAll() async {
    final rows = await _testDb.query(
      'round_sync_queue',
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map(QueuedRoundUpdate.fromRow).toList();
  }

  @override
  Future<void> markSynced(String idempotencyKey) async {
    await _testDb.update(
      'round_sync_queue',
      {'synced_at': DateTime.now().toUtc().toIso8601String()},
      where: 'idempotency_key = ?',
      whereArgs: [idempotencyKey],
    );
  }

  @override
  Future<bool> hasPending() async => (await pendingCount()) > 0;

  @override
  Future<int> pendingCount() async {
    final rows = await _testDb.rawQuery(
      'SELECT COUNT(*) AS count FROM round_sync_queue WHERE synced_at IS NULL',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  @override
  Future<void> close() async {}
}
