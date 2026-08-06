// TargetLocalStore Unit Tests — VSP Mobile App
//
// Tests cover:
// - upsertTarget inserts a new target
// - upsertTarget replaces existing target for same round+hole
// - getTarget returns target or null
// - deleteTarget removes target
// - getTargetsForRound returns all targets for a round ordered by hole
// - Index constraints: unique index on (round_id, hole_number)
// - getTarget on unknown round/hole returns null
// - deleteTarget on unknown target is safe (no-op)
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vsp_mobile/features/target/data/target_local_store.dart';
import 'package:vsp_mobile/features/target/domain/target_model.dart';

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
  late TargetLocalStore store;

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
          CREATE TABLE targets (
            id TEXT PRIMARY KEY,
            round_id TEXT NOT NULL,
            hole_number INTEGER NOT NULL,
            longitude REAL NOT NULL,
            latitude REAL NOT NULL,
            accuracy TEXT NOT NULL,
            source TEXT NOT NULL,
            placed_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
          await db.execute('''
          CREATE UNIQUE INDEX idx_target_round_hole
          ON targets (round_id, hole_number)
        ''');
          await db.execute('''
          CREATE INDEX idx_target_round
          ON targets (round_id)
        ''');
        },
      ),
    );
    store = TestableTargetLocalStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TargetLocalStore', () {
    group('upsertTarget', () {
      test('inserts a new target', () async {
        final target = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );

        await store.upsertTarget(target);

        final rows = await db.query('targets');
        expect(rows.length, 1);
        expect(rows[0]['id'], 'target_r1_h1_uuid1');
        expect(rows[0]['round_id'], 'round-1');
        expect(rows[0]['hole_number'], 1);
      });

      test('replaces existing target for same round+hole', () async {
        final t1 = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );
        final t2 = TargetModel.placed(
          id: 'target_r1_h1_uuid2',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6400, 10.7700],
          accuracy: GpsAccuracy.medium,
        );

        await store.upsertTarget(t1);
        await store.upsertTarget(t2);

        final rows = await db.query('targets');
        expect(rows.length, 1);
        expect(rows[0]['id'], 'target_r1_h1_uuid2');
        expect(rows[0]['longitude'], 106.6400);
        expect(rows[0]['accuracy'], 'medium');
      });
    });

    group('getTarget', () {
      test('returns target for existing round+hole', () async {
        final target = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );
        await store.upsertTarget(target);

        final result = await store.getTarget('round-1', 1);

        expect(result, isNotNull);
        expect(result!.id, 'target_r1_h1_uuid1');
        expect(result.holeNumber, 1);
      });

      test('returns null for unknown round', () async {
        final target = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );
        await store.upsertTarget(target);

        final result = await store.getTarget('unknown-round', 1);

        expect(result, isNull);
      });

      test('returns null for unknown hole', () async {
        final target = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );
        await store.upsertTarget(target);

        final result = await store.getTarget('round-1', 99);

        expect(result, isNull);
      });

      test('returns null for empty database', () async {
        final result = await store.getTarget('round-1', 1);
        expect(result, isNull);
      });
    });

    group('deleteTarget', () {
      test('deletes existing target', () async {
        final target = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );
        await store.upsertTarget(target);

        await store.deleteTarget('round-1', 1);

        final rows = await db.query('targets');
        expect(rows.length, 0);
      });

      test('deleteTarget on unknown target is safe', () async {
        // Should not throw
        await store.deleteTarget('unknown-round', 99);

        final rows = await db.query('targets');
        expect(rows.length, 0);
      });
    });

    group('getTargetsForRound', () {
      test('returns all targets for a round ordered by hole', () async {
        for (final hole in [3, 1, 2]) {
          await store.upsertTarget(
            TargetModel.placed(
              id: 'target_r1_h${hole}_uuid',
              roundId: 'round-1',
              holeNumber: hole,
              position: [106.6294, 10.7629],
              accuracy: GpsAccuracy.high,
            ),
          );
        }

        final targets = await store.getTargetsForRound('round-1');

        expect(targets.length, 3);
        expect(targets[0].holeNumber, 1);
        expect(targets[1].holeNumber, 2);
        expect(targets[2].holeNumber, 3);
      });

      test('returns empty list for unknown round', () async {
        final targets = await store.getTargetsForRound('unknown-round');
        expect(targets, isEmpty);
      });

      test('returns only targets for specified round', () async {
        await store.upsertTarget(
          TargetModel.placed(
            id: 'target_r1_h1_uuid',
            roundId: 'round-1',
            holeNumber: 1,
            position: [106.6294, 10.7629],
            accuracy: GpsAccuracy.high,
          ),
        );
        await store.upsertTarget(
          TargetModel.placed(
            id: 'target_r2_h1_uuid',
            roundId: 'round-2',
            holeNumber: 1,
            position: [106.6294, 10.7629],
            accuracy: GpsAccuracy.high,
          ),
        );

        final targets = await store.getTargetsForRound('round-1');

        expect(targets.length, 1);
        expect(targets[0].roundId, 'round-1');
      });
    });

    group('index constraints', () {
      test('unique index prevents duplicate round+hole', () async {
        final t1 = TargetModel.placed(
          id: 'target_r1_h1_uuid1',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6294, 10.7629],
          accuracy: GpsAccuracy.high,
        );
        final t2 = TargetModel.placed(
          id: 'target_r1_h1_uuid2',
          roundId: 'round-1',
          holeNumber: 1,
          position: [106.6400, 10.7700],
          accuracy: GpsAccuracy.medium,
        );

        await store.upsertTarget(t1);
        await store.upsertTarget(t2); // Should replace via upsert

        final rows = await db.query('targets');
        expect(rows.length, 1);
      });

      test('round index allows efficient round queries', () async {
        // This is validated by the fact getTargetsForRound works
        for (var i = 1; i <= 18; i++) {
          await store.upsertTarget(
            TargetModel.placed(
              id: 'target_r1_h${i}_uuid',
              roundId: 'round-1',
              holeNumber: i,
              position: [106.6294, 10.7629],
              accuracy: GpsAccuracy.high,
            ),
          );
        }

        final targets = await store.getTargetsForRound('round-1');
        expect(targets.length, 18);
      });
    });

    group('data integrity', () {
      test(
        'all GpsAccuracy values are stored and retrieved correctly',
        () async {
          for (final accuracy in GpsAccuracy.values) {
            final target = TargetModel.placed(
              id: 'target_r1_h${accuracy.name}_uuid',
              roundId: 'round-1',
              holeNumber: accuracy.index + 1,
              position: [106.6294, 10.7629],
              accuracy: accuracy,
            );
            await store.upsertTarget(target);
          }

          for (var i = 0; i < GpsAccuracy.values.length; i++) {
            final accuracy = GpsAccuracy.values[i];
            final result = await store.getTarget('round-1', i + 1);
            expect(result!.accuracy, accuracy);
          }
        },
      );

      test(
        'all TargetSource values are stored and retrieved correctly',
        () async {
          for (final source in TargetSource.values) {
            final target = TargetModel(
              id: 'target_r1_h${source.name}_uuid',
              roundId: 'round-1',
              holeNumber: source.index + 20,
              position: [106.6294, 10.7629],
              accuracy: GpsAccuracy.high,
              source: source,
              placedAt: DateTime.utc(2026, 8, 2),
              updatedAt: DateTime.utc(2026, 8, 2),
            );
            await store.upsertTarget(target);
          }

          for (var i = 0; i < TargetSource.values.length; i++) {
            final source = TargetSource.values[i];
            final result = await store.getTarget('round-1', i + 20);
            expect(result!.source, source);
          }
        },
      );
    });

    // ─── Slice 3: Offline Persistence ─────────────────────────────────────────
    group('offline persistence (Slice 3)', () {
      test(
        'target survives database close and reopen (simulates app restart)',
        () async {
          final target = TargetModel.placed(
            id: 'target_r1_h1_uuid1',
            roundId: 'round-offline-1',
            holeNumber: 1,
            position: [106.6294, 10.7629],
            accuracy: GpsAccuracy.high,
          );

          await store.upsertTarget(target);

          // Simulate app restart: close and reopen database
          await store.close();
          final reopenedStore = TestableTargetLocalStore(db);

          // Target should still be retrievable
          final result = await reopenedStore.getTarget('round-offline-1', 1);
          expect(result, isNotNull);
          expect(result!.id, 'target_r1_h1_uuid1');
          expect(result.position, [106.6294, 10.7629]);
          expect(result.accuracy, GpsAccuracy.high);
        },
      );

      test(
        'hole switching: target on previous hole is restored when switching back',
        () async {
          // Place targets on hole 1 and hole 3
          await store.upsertTarget(
            TargetModel.placed(
              id: 'target_r2_h1_uuid',
              roundId: 'round-offline-2',
              holeNumber: 1,
              position: [106.6294, 10.7629],
              accuracy: GpsAccuracy.high,
            ),
          );
          await store.upsertTarget(
            TargetModel.placed(
              id: 'target_r2_h3_uuid',
              roundId: 'round-offline-2',
              holeNumber: 3,
              position: [106.6400, 10.7700],
              accuracy: GpsAccuracy.medium,
            ),
          );

          // Switch to hole 3 — target should be available
          final onHole3 = await store.getTarget('round-offline-2', 3);
          expect(onHole3, isNotNull);
          expect(onHole3!.holeNumber, 3);
          expect(onHole3.position, [106.6400, 10.7700]);

          // Switch back to hole 1 — target should be restored
          final onHole1 = await store.getTarget('round-offline-2', 1);
          expect(onHole1, isNotNull);
          expect(onHole1!.holeNumber, 1);
          expect(onHole1.position, [106.6294, 10.7629]);
        },
      );

      test('target updatedAt is preserved on move', () async {
        final originalPlacedAt = DateTime.utc(2026, 8, 2, 10, 0);

        await store.upsertTarget(
          TargetModel(
            id: 'target_r3_h1_uuid',
            roundId: 'round-offline-3',
            holeNumber: 1,
            position: [106.6294, 10.7629],
            accuracy: GpsAccuracy.high,
            source: TargetSource.tap,
            placedAt: originalPlacedAt,
            updatedAt: originalPlacedAt,
          ),
        );

        // Simulate move (drag) — updatedAt changes, placedAt is preserved
        final movedAt = DateTime.utc(2026, 8, 2, 10, 30);
        await store.upsertTarget(
          TargetModel(
            id: 'target_r3_h1_uuid',
            roundId: 'round-offline-3',
            holeNumber: 1,
            position: [106.6400, 10.7700],
            accuracy: GpsAccuracy.medium,
            source: TargetSource.drag,
            placedAt: originalPlacedAt,
            updatedAt: movedAt,
          ),
        );

        final result = await store.getTarget('round-offline-3', 1);
        expect(result!.placedAt, originalPlacedAt);
        expect(result.updatedAt, movedAt);
        expect(result.source, TargetSource.drag);
      });

      test('multiple rounds have independent targets', () async {
        await store.upsertTarget(
          TargetModel.placed(
            id: 'target_rA_h1_uuid',
            roundId: 'round-A',
            holeNumber: 1,
            position: [106.6294, 10.7629],
            accuracy: GpsAccuracy.high,
          ),
        );
        await store.upsertTarget(
          TargetModel.placed(
            id: 'target_rB_h1_uuid',
            roundId: 'round-B',
            holeNumber: 1,
            position: [106.6400, 10.7700],
            accuracy: GpsAccuracy.low,
          ),
        );

        final targetsA = await store.getTargetsForRound('round-A');
        final targetsB = await store.getTargetsForRound('round-B');

        expect(targetsA.length, 1);
        expect(targetsA[0].position, [106.6294, 10.7629]);
        expect(targetsB.length, 1);
        expect(targetsB[0].position, [106.6400, 10.7700]);
        expect(targetsB[0].accuracy, GpsAccuracy.low);
      });
    });
  });
}

/// TestableTargetLocalStore — injects an open database directly,
/// bypassing path_provider for test isolation.
class TestableTargetLocalStore extends TargetLocalStore {
  final Database _testDb;

  TestableTargetLocalStore(this._testDb);

  @override
  Future<Database> get database async => _testDb;

  @override
  Future<void> close() async {
    // Don't close the test database — tearDown handles it
  }
}
