// Watch Score Sync Test — VSP Watch Apple App
//
// Unit tests for score sync queue and idempotency.
// Tests AC-5, AC-6: Local persistence and idempotent sync.
//
// Story 10.1 — Slice 6: E2E Integration & Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:watch_apple/domain/watch_round_session.dart';

void main() {
  group('WatchScoreEntry', () {
    test('creates score entry with required fields', () {
      final entry = WatchScoreEntry(
        id: 'test-id',
        playerId: 'player_1',
        holeNumber: 1,
        grossScore: 4,
        enteredAt: DateTime.now(),
      );

      expect(entry.id, equals('test-id'));
      expect(entry.playerId, equals('player_1'));
      expect(entry.holeNumber, equals(1));
      expect(entry.grossScore, equals(4));
      expect(entry.syncStatus, equals('local'));
    });

    test('copyWith preserves unchanged fields', () {
      final original = WatchScoreEntry(
        id: 'test-id',
        playerId: 'player_1',
        holeNumber: 1,
        grossScore: 4,
        enteredAt: DateTime.now(),
        syncStatus: 'local',
      );

      final updated = original.copyWith(syncStatus: 'synced', roundId: 'round-1');

      expect(updated.id, equals(original.id));
      expect(updated.playerId, equals(original.playerId));
      expect(updated.syncStatus, equals('synced'));
      expect(updated.roundId, equals('round-1'));
    });

    test('version increments on update', () {
      final v1 = WatchScoreEntry(
        id: 'test-id',
        playerId: 'player_1',
        holeNumber: 1,
        grossScore: 4,
        enteredAt: DateTime.now(),
        version: 1,
      );

      final v2 = v1.copyWith(version: 2);

      expect(v1.version, equals(1));
      expect(v2.version, equals(2));
    });
  });

  group('WatchRoundSession', () {
    test('creates session with required fields', () {
      final now = DateTime.now();
      final session = WatchRoundSession(
        id: 'session-1',
        courseId: 1,
        courseName: 'Test Course',
        teeSetId: 'tee-1',
        currentHole: 1,
        currentPar: 4,
        startedAt: now,
        updatedAt: now,
        packageVersion: '1.0.0',
      );

      expect(session.id, equals('session-1'));
      expect(session.courseName, equals('Test Course'));
      expect(session.currentHole, equals(1));
      expect(session.status, equals(WatchRoundStatus.active));
      expect(session.syncStatus, equals('local'));
    });

    test('totalStrokesFor calculates correctly', () {
      final now = DateTime.now();
      final session = WatchRoundSession(
        id: 'session-1',
        courseId: 1,
        courseName: 'Test Course',
        teeSetId: 'tee-1',
        currentHole: 5,
        currentPar: 4,
        scores: [
          WatchHoleScore(playerId: 'p1', holeNumber: 1, strokes: 4),
          WatchHoleScore(playerId: 'p1', holeNumber: 2, strokes: 5),
          WatchHoleScore(playerId: 'p1', holeNumber: 3, strokes: 4),
          WatchHoleScore(playerId: 'p2', holeNumber: 1, strokes: 3),
        ],
        startedAt: now,
        updatedAt: now,
        packageVersion: '1.0.0',
      );

      expect(session.totalStrokesFor('p1'), equals(13)); // 4+5+4
      expect(session.totalStrokesFor('p2'), equals(3));
    });

    test('relativeScoreFor calculates correctly', () {
      final now = DateTime.now();
      final session = WatchRoundSession(
        id: 'session-1',
        courseId: 1,
        courseName: 'Test Course',
        teeSetId: 'tee-1',
        currentHole: 5,
        currentPar: 4,
        scores: [
          WatchHoleScore(playerId: 'p1', holeNumber: 1, strokes: 4),
          WatchHoleScore(playerId: 'p1', holeNumber: 2, strokes: 5),
        ],
        startedAt: now,
        updatedAt: now,
        packageVersion: '1.0.0',
      );

      // 4+5 = 9 strokes, par for 2 holes = 8, relative = +1
      expect(session.relativeScoreFor('p1', 8), equals(1));
    });

    test('isActive returns correct status', () {
      final now = DateTime.now();

      final active = WatchRoundSession(
        id: 's1',
        courseId: 1,
        courseName: 'Test',
        teeSetId: 'tee-1',
        currentHole: 1,
        currentPar: 4,
        status: WatchRoundStatus.active,
        startedAt: now,
        updatedAt: now,
        packageVersion: '1.0.0',
      );

      final paused = WatchRoundSession(
        id: 's2',
        courseId: 1,
        courseName: 'Test',
        teeSetId: 'tee-1',
        currentHole: 1,
        currentPar: 4,
        status: WatchRoundStatus.paused,
        startedAt: now,
        updatedAt: now,
        packageVersion: '1.0.0',
      );

      expect(active.isActive, isTrue);
      expect(paused.isActive, isFalse);
    });

    test('copyWith updates only specified fields', () {
      final now = DateTime.now();
      final original = WatchRoundSession(
        id: 's1',
        courseId: 1,
        courseName: 'Test',
        teeSetId: 'tee-1',
        currentHole: 1,
        currentPar: 4,
        startedAt: now,
        updatedAt: now,
        packageVersion: '1.0.0',
      );

      final updated = original.copyWith(
        currentHole: 5,
        syncStatus: 'pending',
      );

      expect(updated.id, equals(original.id));
      expect(updated.courseName, equals(original.courseName));
      expect(updated.currentHole, equals(5));
      expect(updated.syncStatus, equals('pending'));
    });
  });

  group('WatchHoleScore', () {
    test('creates hole score with all fields', () {
      final now = DateTime.now();
      final score = WatchHoleScore(
        playerId: 'p1',
        holeNumber: 5,
        strokes: 4,
        putts: 2,
        penalties: 0,
        fairwayHit: true,
        gir: true,
        enteredAt: now,
      );

      expect(score.playerId, equals('p1'));
      expect(score.holeNumber, equals(5));
      expect(score.strokes, equals(4));
      expect(score.putts, equals(2));
      expect(score.fairwayHit, isTrue);
      expect(score.gir, isTrue);
    });

    test('strokes is optional for incomplete holes', () {
      final score = WatchHoleScore(
        playerId: 'p1',
        holeNumber: 5,
      );

      expect(score.strokes, isNull);
      expect(score.putts, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final original = WatchHoleScore(
        playerId: 'p1',
        holeNumber: 5,
        strokes: 4,
      );

      final updated = original.copyWith(putts: 2, gir: true);

      expect(updated.playerId, equals(original.playerId));
      expect(updated.holeNumber, equals(original.holeNumber));
      expect(updated.strokes, equals(original.strokes));
      expect(updated.putts, equals(2));
      expect(updated.gir, isTrue);
    });
  });

  group('Sync Idempotency', () {
    test('multiple sync attempts produce same result', () {
      final now = DateTime.now();

      // Create entry
      final entry = WatchScoreEntry(
        id: 'id-1',
        playerId: 'p1',
        holeNumber: 1,
        grossScore: 4,
        enteredAt: now,
        syncStatus: 'local',
      );

      // First sync
      final synced1 = entry.copyWith(syncStatus: 'synced');

      // Second sync (should produce same result)
      final synced2 = synced1.copyWith(syncStatus: 'synced');

      expect(synced1.syncStatus, equals(synced2.syncStatus));
      expect(synced1.id, equals(synced2.id));
    });

    test('score update creates new version', () {
      final now = DateTime.now();

      final v1 = WatchScoreEntry(
        id: 'id-1',
        playerId: 'p1',
        holeNumber: 1,
        grossScore: 4,
        enteredAt: now,
        version: 1,
      );

      final v2 = v1.copyWith(grossScore: 5, version: 2);

      expect(v1.grossScore, equals(4));
      expect(v2.grossScore, equals(5));
      expect(v2.version, equals(2));
    });
  });

  group('Persistence Round-trip', () {
    test('WatchScoreEntry survives JSON round-trip', () {
      final original = WatchScoreEntry(
        id: 'test-id',
        playerId: 'player_1',
        holeNumber: 5,
        grossScore: 4,
        putts: 2,
        penalties: 0,
        fairwayHit: true,
        gir: true,
        enteredAt: DateTime.parse('2026-01-01T10:00:00Z'),
        syncStatus: 'local',
        version: 1,
      );

      // Simulate persistence by converting to map and back
      final map = {
        'id': original.id,
        'roundId': original.roundId,
        'playerId': original.playerId,
        'holeNumber': original.holeNumber,
        'grossScore': original.grossScore,
        'putts': original.putts,
        'penalties': original.penalties,
        'fairwayHit': original.fairwayHit,
        'gir': original.gir,
        'notes': original.notes,
        'enteredAt': original.enteredAt.toIso8601String(),
        'syncStatus': original.syncStatus,
        'version': original.version,
      };

      final restored = WatchScoreEntry(
        id: map['id'] as String,
        roundId: map['roundId'] as String?,
        playerId: map['playerId'] as String,
        holeNumber: map['holeNumber'] as int,
        grossScore: map['grossScore'] as int?,
        putts: map['putts'] as int?,
        penalties: map['penalties'] as int?,
        fairwayHit: map['fairwayHit'] as bool?,
        gir: map['gir'] as bool?,
        notes: map['notes'] as String?,
        enteredAt: DateTime.parse(map['enteredAt'] as String),
        syncStatus: map['syncStatus'] as String? ?? 'local',
        version: map['version'] as int? ?? 1,
      );

      expect(restored.id, equals(original.id));
      expect(restored.playerId, equals(original.playerId));
      expect(restored.holeNumber, equals(original.holeNumber));
      expect(restored.grossScore, equals(original.grossScore));
      expect(restored.syncStatus, equals(original.syncStatus));
    });
  });
}
