// Round integration tests — VSP Mobile App
//
// Integration tests covering cross-component round persistence flows.
//
// Tests cover (per Slice 6 PERSIST-TEST acceptance criteria):
// - Restart recovery: create round, simulate app restart, verify round restored
// - Transactional round creation: round + players persisted atomically
// - Score round-trip: add score, retrieve, verify all fields
// - Sync queue processing: enqueue 3 operations, dequeue, mark one synced,
//   verify correct remaining count
// - Edge case: duplicate idempotency key → payload updated, not duplicated
// - Edge case: empty round list → getActiveRound() returns null
// - Edge case: score for non-existent round → handled gracefully

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:uuid/uuid.dart';
import 'package:vsp_mobile/data/repositories/hole_score_repository.dart';
import 'package:vsp_mobile/data/repositories/player_repository.dart';
import 'package:vsp_mobile/data/repositories/round_repository.dart';
import 'package:vsp_mobile/domain/models/hole_score.dart';
import 'package:vsp_mobile/domain/models/player.dart';
import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/domain/models/round_sync_operation.dart';
import 'package:vsp_mobile/core/storage/round_sync_store.dart';

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

  group('Round persistence integration tests', () {
    late Database db;
    late RoundRepository roundRepo;
    late HoleScoreRepository scoreRepo;
    late PlayerRepository playerRepo;
    late RoundSyncStore syncStore;

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
            CREATE INDEX idx_hole_scores_hole ON hole_scores (round_id, hole_number)
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
    });

    tearDown(() async {
      await db.close();
    });

    // -------------------------------------------------------------------------
    // Restart recovery test
    // Simulates: create round → kill app → relaunch → query active round
    // Corresponds to: Slice 6 AC – "Restart recovery: simulate app restart,
    // verify round restored" and Slice 4 AC-2 ("App restart restores an
    // incomplete round")
    // -------------------------------------------------------------------------

    test(
      'restart recovery: active round is recoverable after app restart',
      () async {
        // Step 1: Start a round (simulates startRound)
        final now = DateTime.now();
        final roundId = const Uuid().v4();
        final round = Round(
          id: roundId,
          courseId: 42,
          courseName: 'Pebble Beach',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1.2.0',
          createdAt: now,
          updatedAt: now,
        );

        // Persist round + player atomically
        await roundRepo.transactional((txn) async {
          await txn.insert('rounds', round.toMap());
          await txn.insert('players', {
            'id': 'player-1',
            'round_id': roundId,
            'name': 'Carol',
            'handicap': 14.0,
            'is_current_user': 1,
          });
        });

        // Persist a hole score
        final score = HoleScore(
          id: const Uuid().v4(),
          roundId: roundId,
          holeNumber: 4,
          par: 5,
          strokes: 5,
          putts: 2,
          createdAt: now,
          updatedAt: now,
        );
        await scoreRepo.createScore(score);

        // Enqueue a sync event
        await syncStore.enqueueRoundOp(
          idempotencyKey: 'round_${roundId}_startRound_1000',
          operation: RoundSyncOperation.startRound,
          roundId: roundId,
          payload: '{"courseId":42}',
        );

        // Step 2: Simulate app restart — create fresh repository instances
        // sharing the same underlying database (same connection in this test)
        final restartedRoundRepo = TestableRoundRepository(db);
        final restartedScoreRepo = TestableHoleScoreRepository(db);
        final restartedSyncRepo = TestableRoundSyncStore(db);

        // Step 3: recoverActiveRound — queries for status = 'in_progress'
        final recoveredRound = await restartedRoundRepo.getActiveRound();

        expect(recoveredRound, isNotNull);
        expect(recoveredRound!.id, roundId);
        expect(recoveredRound.courseName, 'Pebble Beach');
        expect(recoveredRound.status, RoundStatus.inProgress);
        expect(recoveredRound.packageVersion, 'v1.2.0');

        // Step 4: Verify hole score is also recoverable
        final recoveredScores = await restartedScoreRepo.getScoresForRound(
          roundId,
        );
        expect(recoveredScores.length, 1);
        expect(recoveredScores[0].holeNumber, 4);
        expect(recoveredScores[0].par, 5);

        // Step 5: Verify sync event is still pending
        final recoveredPending = await restartedSyncRepo.dequeueAll();
        expect(recoveredPending.length, 1);
        expect(recoveredPending[0].operation, RoundSyncOperation.startRound);
      },
    );

    // -------------------------------------------------------------------------
    // Transactional round creation test
    // Corresponds to: Slice 6 AC "Transactional round creation (round +
    // players persisted atomically)" and Slice 2 AC-1 ("Round state changes
    // written in a single SQLite transaction; no partial writes")
    // -------------------------------------------------------------------------

    test(
      'transactional round creation: round and players are persisted atomically',
      () async {
        final now = DateTime.now();
        final roundId = const Uuid().v4();
        final round = Round(
          id: roundId,
          courseId: 7,
          courseName: 'St Andrews',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1.0.0',
          createdAt: now,
          updatedAt: now,
        );

        final players = [
          const Player(id: 'p1', name: 'Dave', isPrimary: true),
          const Player(id: 'p2', name: 'Eve', isPrimary: false),
          const Player(id: 'p3', name: 'Frank', isPrimary: false),
        ];

        // Atomic insert
        await roundRepo.transactional((txn) async {
          await txn.insert('rounds', round.toMap());
          for (final p in players) {
            await txn.insert('players', p.toMap(roundId));
          }
        });

        // Verify round persisted
        final savedRound = await roundRepo.getRound(roundId);
        expect(savedRound, isNotNull);
        expect(savedRound!.courseName, 'St Andrews');

        // Verify all players persisted
        final savedPlayers = await playerRepo.getPlayersForRound(roundId);
        expect(savedPlayers.length, 3);

        // Verify each player has correct data
        final primary = savedPlayers.firstWhere((p) => p.id == 'p1');
        expect(primary.isPrimary, isTrue);

        final secondary = savedPlayers.firstWhere((p) => p.id == 'p2');
        expect(secondary.isPrimary, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // Score round-trip test
    // Corresponds to: Slice 6 AC "Score round-trip: add score, retrieve,
    // verify all fields"
    // -------------------------------------------------------------------------

    test(
      'score round-trip: all fields preserved across insert and retrieve',
      () async {
        final roundId = const Uuid().v4();
        final now = DateTime.now();

        // Persist a round first
        final round = Round(
          id: roundId,
          courseId: 10,
          courseName: 'Bethpage Black',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v1',
          createdAt: now,
          updatedAt: now,
        );
        await roundRepo.createRound(round);

        // Create a fully-populated hole score
        final score = HoleScore(
          id: const Uuid().v4(),
          roundId: roundId,
          holeNumber: 9,
          par: 4,
          strokes: 5,
          putts: 2,
          penalties: 1,
          fairwayHit: false,
          gir: true,
          clubUsed: '6i',
          notes: 'Pushed right off tee',
          createdAt: now,
          updatedAt: now,
        );

        await scoreRepo.createScore(score);

        // Retrieve and verify
        final retrieved = await scoreRepo.getScoreForHole(roundId, 9);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, score.id);
        expect(retrieved.roundId, roundId);
        expect(retrieved.holeNumber, 9);
        expect(retrieved.par, 4);
        expect(retrieved.strokes, 5);
        expect(retrieved.putts, 2);
        expect(retrieved.penalties, 1);
        expect(retrieved.fairwayHit, isFalse);
        expect(retrieved.gir, isTrue);
        expect(retrieved.clubUsed, '6i');
        expect(retrieved.notes, 'Pushed right off tee');
        expect(retrieved.scoreToPar, 1); // 5 - 4 = +1
      },
    );

    // -------------------------------------------------------------------------
    // Sync queue test
    // Corresponds to: Slice 6 AC "Sync queue: enqueue 3 operations, dequeue,
    // mark one synced — correct remaining count"
    // -------------------------------------------------------------------------

    test(
      'sync queue: enqueue 3 operations, dequeue, mark one synced — correct remaining count',
      () async {
        final roundId = const Uuid().v4();

        await syncStore.enqueueRoundOp(
          idempotencyKey: 'op-1',
          operation: RoundSyncOperation.startRound,
          roundId: roundId,
          payload: '{"type":"start"}',
        );
        await syncStore.enqueueRoundOp(
          idempotencyKey: 'op-2',
          operation: RoundSyncOperation.updateHoleScore,
          roundId: roundId,
          payload: '{"type":"update"}',
        );
        await syncStore.enqueueRoundOp(
          idempotencyKey: 'op-3',
          operation: RoundSyncOperation.endRound,
          roundId: roundId,
          payload: '{"type":"end"}',
        );

        // Dequeue all 3
        final pending = await syncStore.dequeueAll();
        expect(pending.length, 3);

        // Mark op-2 as synced
        await syncStore.markSynced('op-2');

        // Verify: 2 remaining
        final remaining = await syncStore.dequeueAll();
        expect(remaining.length, 2);
        expect(
          remaining.map((e) => e.idempotencyKey),
          containsAll(['op-1', 'op-3']),
        );
        expect(remaining.any((e) => e.idempotencyKey == 'op-2'), isFalse);

        // pendingCount should be 2
        expect(await syncStore.pendingCount(), 2);
      },
    );

    // -------------------------------------------------------------------------
    // Edge case: duplicate idempotency key → payload updated, not duplicated
    // Corresponds to: Slice 6 AC "Duplicate idempotency key → payload updated,
    // not duplicated"
    // -------------------------------------------------------------------------

    test(
      'idempotency key deduplication: duplicate key updates payload, no duplicate entry',
      () async {
        final roundId = const Uuid().v4();

        await syncStore.enqueueRoundOp(
          idempotencyKey: 'dedup-key',
          operation: RoundSyncOperation.updateHoleScore,
          roundId: roundId,
          payload: '{"hole":1,"strokes":4}',
        );

        await syncStore.enqueueRoundOp(
          idempotencyKey: 'dedup-key',
          operation: RoundSyncOperation.updateHoleScore,
          roundId: roundId,
          payload: '{"hole":1,"strokes":5}', // Updated strokes
        );

        final pending = await syncStore.dequeueAll();
        expect(pending.length, 1, reason: 'No duplicate entry should exist');
        expect(pending[0].payload, '{"hole":1,"strokes":5}');
      },
    );

    // -------------------------------------------------------------------------
    // Edge case: empty round list → getActiveRound() returns null
    // Corresponds to: Slice 6 AC "Empty round list → getActiveRound() returns null"
    // -------------------------------------------------------------------------

    test('empty round list: getActiveRound() returns null', () async {
      final result = await roundRepo.getActiveRound();
      expect(result, isNull);
    });

    // -------------------------------------------------------------------------
    // Edge case: score for non-existent round → handled gracefully
    // Corresponds to: Slice 6 AC "Score for non-existent round → handled gracefully"
    // -------------------------------------------------------------------------

    test(
      'score for non-existent round: getScoresForRound returns empty list',
      () async {
        final scores = await scoreRepo.getScoresForRound(
          'non-existent-round-id',
        );
        expect(scores, isEmpty);
      },
    );

    test(
      'score for non-existent round: getScoreForHole returns null',
      () async {
        final score = await scoreRepo.getScoreForHole(
          'non-existent-round-id',
          1,
        );
        expect(score, isNull);
      },
    );

    // -------------------------------------------------------------------------
    // Full round lifecycle integration test
    // Covers: start → score → end → verify all data correct
    // -------------------------------------------------------------------------

    test(
      'full round lifecycle: start → score → end → verify data integrity',
      () async {
        final now = DateTime.now();
        final roundId = const Uuid().v4();

        // Start round
        final round = Round(
          id: roundId,
          courseId: 100,
          courseName: 'Royal Melbourne',
          status: RoundStatus.inProgress,
          startedAt: now,
          endedAt: null,
          packageVersion: 'v2.0.0',
          createdAt: now,
          updatedAt: now,
        );
        await roundRepo.transactional((txn) async {
          await txn.insert('rounds', round.toMap());
          await txn.insert('players', {
            'id': 'player-main',
            'round_id': roundId,
            'name': 'George',
            'handicap': 18,
            'is_current_user': 1,
          });
        });

        // Score hole 1
        final score1 = HoleScore(
          id: const Uuid().v4(),
          roundId: roundId,
          holeNumber: 1,
          par: 4,
          strokes: 5,
          putts: 2,
          createdAt: now,
          updatedAt: now,
        );
        await scoreRepo.createScore(score1);

        // Enqueue sync events
        await syncStore.enqueueRoundOp(
          idempotencyKey: 'op-start',
          operation: RoundSyncOperation.startRound,
          roundId: roundId,
          payload: '{}',
        );
        await syncStore.enqueueRoundOp(
          idempotencyKey: 'op-score-1',
          operation: RoundSyncOperation.updateHoleScore,
          roundId: roundId,
          payload: '{"hole":1}',
        );

        // Verify state after scoring
        expect((await roundRepo.getActiveRound())!.id, roundId);
        expect((await scoreRepo.getScoresForRound(roundId)).length, 1);
        expect(await syncStore.pendingCount(), 2);

        // End round
        final updatedRound = round.copyWith(
          status: RoundStatus.completed,
          endedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await roundRepo.updateRound(updatedRound);

        await syncStore.enqueueRoundOp(
          idempotencyKey: 'op-end',
          operation: RoundSyncOperation.endRound,
          roundId: roundId,
          payload: '{}',
        );

        // Verify final state
        final finalRound = await roundRepo.getRound(roundId);
        expect(finalRound!.status, RoundStatus.completed);
        expect(finalRound.endedAt, isNotNull);

        expect(await roundRepo.getActiveRound(), isNull); // No more in-progress
        expect(await syncStore.pendingCount(), 3);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Testable repositories (inject in-memory DB, same pattern as bag tests)
// ---------------------------------------------------------------------------

class TestableRoundRepository extends RoundRepository {
  final Database _testDb;
  TestableRoundRepository(this._testDb);
  @override
  Future<Database> get database async => _testDb;
  @override
  Future<void> close() async {}
}

class TestableHoleScoreRepository extends HoleScoreRepository {
  final Database _testDb;
  TestableHoleScoreRepository(this._testDb);
  @override
  Future<Database> get database async => _testDb;
  @override
  Future<void> close() async {}
}

class TestablePlayerRepository extends PlayerRepository {
  final Database _testDb;
  TestablePlayerRepository(this._testDb);
  @override
  Future<Database> get database async => _testDb;
  @override
  Future<void> close() async {}
}

class TestableRoundSyncStore extends RoundSyncStore {
  final Database _testDb;
  TestableRoundSyncStore(this._testDb);
  @override
  Future<Database> get database async => _testDb;
  @override
  Future<void> close() async {}
}
