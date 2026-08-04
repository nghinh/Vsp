// HoleScoreRepository unit tests — VSP Mobile App
//
// Tests cover:
// - createScore and getScoreForHole round-trip
// - updateScore persists changes
// - deleteScore removes entry
// - getScoresForRound returns all scores for a round ordered by hole_number
// - Score for non-existent round returns empty list
// - Bool fields (fairwayHit, gir) serialize/deserialize correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uuid/uuid.dart';
import 'package:vsp_mobile/data/repositories/hole_score_repository.dart';
import 'package:vsp_mobile/domain/models/hole_score.dart';

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
  late HoleScoreRepository repo;
  late String roundId;

  setUpAll(() {
    PathProviderPlatform.instance = FakePathProvider();
  });

  setUp(() async {
    roundId = const Uuid().v4();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
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
        },
      ),
    );
    repo = TestableHoleScoreRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  HoleScore makeScore({
    String? id,
    int holeNumber = 1,
    int par = 4,
    int strokes = 4,
    int? putts = 2,
    int? penalties = 0,
    bool? fairwayHit = true,
    bool? gir = true,
    String? clubUsed = '7i',
    String? notes = 'Good shot',
  }) {
    final now = DateTime.now();
    return HoleScore(
      id: id ?? const Uuid().v4(),
      roundId: roundId,
      holeNumber: holeNumber,
      par: par,
      strokes: strokes,
      putts: putts,
      penalties: penalties,
      fairwayHit: fairwayHit,
      gir: gir,
      clubUsed: clubUsed,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('HoleScoreRepository', () {
    group('createScore and getScoreForHole', () {
      test('inserts score and retrieves it by roundId + holeNumber', () async {
        final score = makeScore(holeNumber: 5, par: 3, strokes: 3);

        await repo.createScore(score);
        final retrieved = await repo.getScoreForHole(roundId, 5);

        expect(retrieved, isNotNull);
        expect(retrieved!.id, score.id);
        expect(retrieved.holeNumber, 5);
        expect(retrieved.par, 3);
        expect(retrieved.strokes, 3);
      });

      test('getScoreForHole returns null for non-existent hole', () async {
        final result = await repo.getScoreForHole(roundId, 99);
        expect(result, isNull);
      });

      test('getScoreForHole returns null for non-existent round', () async {
        final score = makeScore();
        await repo.createScore(score);

        final result = await repo.getScoreForHole('non-existent-round', 1);
        expect(result, isNull);
      });

      test(
        'fairwayHit and gir serialize/deserialize as null correctly',
        () async {
          final scoreNoBooleans = makeScore(fairwayHit: null, gir: null);
          await repo.createScore(scoreNoBooleans);

          final retrieved = await repo.getScoreForHole(roundId, 1);
          expect(retrieved!.fairwayHit, isNull);
          expect(retrieved.gir, isNull);
        },
      );

      test(
        'fairwayHit and gir serialize/deserialize as true/false correctly',
        () async {
          final scoreHit = makeScore(fairwayHit: true, gir: true);
          await repo.createScore(scoreHit);

          final retrieved = await repo.getScoreForHole(roundId, 1);
          expect(retrieved!.fairwayHit, isTrue);
          expect(retrieved.gir, isTrue);
        },
      );
    });

    group('updateScore', () {
      test('updateScore persists changed fields', () async {
        final score = makeScore(strokes: 4, putts: 2);
        await repo.createScore(score);

        final updated = score.copyWith(strokes: 5, putts: 3);
        await repo.updateScore(updated);

        final retrieved = await repo.getScoreForHole(roundId, 1);
        expect(retrieved!.strokes, 5);
        expect(retrieved.putts, 3);
      });
    });

    group('deleteScore', () {
      test('deleteScore removes the entry', () async {
        final score = makeScore();
        await repo.createScore(score);

        await repo.deleteScore(score.id);

        final retrieved = await repo.getScoreForHole(roundId, 1);
        expect(retrieved, isNull);
      });

      test('deleteScore is safe for non-existent id', () async {
        // Should not throw
        await repo.deleteScore('non-existent-id');
      });
    });

    group('getScoresForRound', () {
      test(
        'returns all scores for a round ordered by hole_number ASC',
        () async {
          final s1 = makeScore(
            id: const Uuid().v4(),
            holeNumber: 3,
            strokes: 3,
          );
          final s2 = makeScore(
            id: const Uuid().v4(),
            holeNumber: 1,
            strokes: 4,
          );
          final s3 = makeScore(
            id: const Uuid().v4(),
            holeNumber: 5,
            strokes: 5,
          );

          await repo.createScore(s1);
          await repo.createScore(s2);
          await repo.createScore(s3);

          final scores = await repo.getScoresForRound(roundId);

          expect(scores.length, 3);
          expect(scores[0].holeNumber, 1);
          expect(scores[1].holeNumber, 3);
          expect(scores[2].holeNumber, 5);
        },
      );

      test('returns empty list for round with no scores', () async {
        final scores = await repo.getScoresForRound('round-with-no-scores');
        expect(scores, isEmpty);
      });

      test('scoreToPar computed getter is correct', () async {
        final overPar = makeScore(par: 4, strokes: 6);
        final underPar = makeScore(
          id: const Uuid().v4(),
          holeNumber: 2,
          par: 4,
          strokes: 3,
        );
        final atPar = makeScore(
          id: const Uuid().v4(),
          holeNumber: 3,
          par: 4,
          strokes: 4,
        );

        await repo.createScore(overPar);
        await repo.createScore(underPar);
        await repo.createScore(atPar);

        final scores = await repo.getScoresForRound(roundId);
        expect(scores[0].scoreToPar, 2); // 6 - 4
        expect(scores[1].scoreToPar, -1); // 3 - 4
        expect(scores[2].scoreToPar, 0); // 4 - 4
      });
    });
  });
}

/// TestableHoleScoreRepository — injects an open database directly,
/// bypassing path_provider for test isolation.
class TestableHoleScoreRepository extends HoleScoreRepository {
  final Database _testDb;

  TestableHoleScoreRepository(this._testDb);

  @override
  Future<Database> get database async => _testDb;

  @override
  Future<void> close() async {
    // Don't close the test database — tearDown handles it
  }
}
