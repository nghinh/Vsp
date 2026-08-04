// RoundSyncStore unit tests — VSP Mobile App
//
// Tests cover:
// - enqueue persists operation to SQLite
// - dequeueAll returns pending entries in creation order
// - markSynced marks entry as synced
// - hasPending returns true when queue has entries
// - pendingCount returns correct count
// - idempotency key uniqueness: duplicate key replaces pending entry
// - duplicate key resets synced_at (re-queues)
// - purgeSynced removes only synced entries
// - incrementRetry increments retry count
// - All RoundSyncOperation types parse correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vsp_mobile/core/storage/round_sync_store.dart';
import 'package:vsp_mobile/domain/models/round_sync_operation.dart';

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
  late RoundSyncStore store;

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
    store = TestableRoundSyncStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('RoundSyncStore', () {
    group('enqueue and dequeueAll', () {
      test('enqueue inserts a pending startRound entry', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{"courseId":1}',
        );

        final pending = await store.dequeueAll();

        expect(pending.length, 1);
        expect(pending[0].idempotencyKey, 'key-1');
        expect(pending[0].operation, RoundSyncOperation.startRound);
        expect(pending[0].roundId, 'round-1');
        expect(pending[0].isSynced, isFalse);
      });

      test('enqueue inserts entry with all operation types', () async {
        for (final op in RoundSyncOperation.values) {
          final key = 'key-${op.name}';
          await store.enqueueRoundOp(
            idempotencyKey: key,
            operation: op,
            roundId: 'round-1',
            payload: '{}',
          );
        }

        final pending = await store.dequeueAll();

        expect(pending.length, RoundSyncOperation.values.length);
        for (final op in RoundSyncOperation.values) {
          expect(pending.any((e) => e.operation == op), isTrue);
        }
      });

      test(
        'dequeueAll returns pending entries ordered by created_at ASC',
        () async {
          await store.enqueueRoundOp(
            idempotencyKey: 'key-1',
            operation: RoundSyncOperation.startRound,
            roundId: 'round-1',
            payload: '{"n":1}',
          );
          await Future.delayed(const Duration(milliseconds: 10));
          await store.enqueueRoundOp(
            idempotencyKey: 'key-2',
            operation: RoundSyncOperation.updateHoleScore,
            roundId: 'round-1',
            payload: '{"n":2}',
          );
          await Future.delayed(const Duration(milliseconds: 10));
          await store.enqueueRoundOp(
            idempotencyKey: 'key-3',
            operation: RoundSyncOperation.endRound,
            roundId: 'round-1',
            payload: '{"n":3}',
          );

          final pending = await store.dequeueAll();

          expect(pending.length, 3);
          expect(pending[0].idempotencyKey, 'key-1');
          expect(pending[1].idempotencyKey, 'key-2');
          expect(pending[2].idempotencyKey, 'key-3');
        },
      );

      test('dequeueAll excludes synced entries', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{}',
        );
        await store.markSynced('key-1');

        final pending = await store.dequeueAll();

        expect(pending.length, 0);
      });
    });

    group('markSynced', () {
      test('sets synced_at timestamp', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.endRound,
          roundId: 'round-1',
          payload: '{}',
        );

        await store.markSynced('key-1');

        final rows = await db.query(
          'round_sync_queue',
          where: 'idempotency_key = ?',
          whereArgs: ['key-1'],
        );
        expect(rows[0]['synced_at'], isNotNull);
        expect(rows[0]['synced_at'] as String, isNotEmpty);
      });

      test('markSynced on unknown key is safe (no-op)', () async {
        // Should not throw
        await store.markSynced('unknown-key');
      });
    });

    group('hasPending and pendingCount', () {
      test('hasPending returns false initially', () async {
        expect(await store.hasPending(), isFalse);
      });

      test('hasPending returns true when queue has unsynced entries', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{}',
        );
        expect(await store.hasPending(), isTrue);
      });

      test(
        'hasPending returns false after all entries are marked synced',
        () async {
          await store.enqueueRoundOp(
            idempotencyKey: 'key-1',
            operation: RoundSyncOperation.startRound,
            roundId: 'round-1',
            payload: '{}',
          );
          await store.markSynced('key-1');
          expect(await store.hasPending(), isFalse);
        },
      );

      test('pendingCount returns correct count', () async {
        expect(await store.pendingCount(), 0);

        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{}',
        );
        await store.enqueueRoundOp(
          idempotencyKey: 'key-2',
          operation: RoundSyncOperation.updateHoleScore,
          roundId: 'round-1',
          payload: '{}',
        );
        expect(await store.pendingCount(), 2);

        await store.markSynced('key-1');
        expect(await store.pendingCount(), 1);
      });
    });

    group('incrementRetry', () {
      test('increments retry count for an entry', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.updateHoleScore,
          roundId: 'round-1',
          payload: '{}',
        );

        await store.incrementRetry('key-1');

        final pending = await store.dequeueAll();
        expect(pending[0].retryCount, 1);
      });
    });

    group('purgeSynced', () {
      test('removes only synced entries', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{}',
        );
        await store.enqueueRoundOp(
          idempotencyKey: 'key-2',
          operation: RoundSyncOperation.updateHoleScore,
          roundId: 'round-1',
          payload: '{}',
        );
        await store.markSynced('key-1');

        final purged = await store.purgeSynced();

        expect(purged, 1);
        expect(await store.pendingCount(), 1);
        final remaining = await store.dequeueAll();
        expect(remaining[0].idempotencyKey, 'key-2');
      });

      test('purgeSynced returns 0 when no synced entries', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{}',
        );

        final purged = await store.purgeSynced();
        expect(purged, 0);
      });
    });

    group('idempotency key uniqueness', () {
      test(
        'enqueue with duplicate key replaces pending entry payload',
        () async {
          await store.enqueueRoundOp(
            idempotencyKey: 'same-key',
            operation: RoundSyncOperation.startRound,
            roundId: 'round-1',
            payload: '{"version":1}',
          );
          await store.enqueueRoundOp(
            idempotencyKey: 'same-key',
            operation: RoundSyncOperation.updateHoleScore,
            roundId: 'round-1',
            payload: '{"version":2}',
          );

          final pending = await store.dequeueAll();

          expect(pending.length, 1);
          expect(pending[0].idempotencyKey, 'same-key');
          expect(pending[0].payload, '{"version":2}');
          expect(pending[0].operation, RoundSyncOperation.updateHoleScore);
        },
      );

      test('enqueue with duplicate key resets synced_at (re-queues)', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{"v":1}',
        );
        await store.markSynced('key-1');

        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.endRound,
          roundId: 'round-1',
          payload: '{"v":2}',
        );

        final pending = await store.dequeueAll();

        expect(pending.length, 1);
        expect(pending[0].idempotencyKey, 'key-1');
        expect(pending[0].isSynced, isFalse);
        expect(pending[0].payload, '{"v":2}');
        expect(pending[0].operation, RoundSyncOperation.endRound);
      });

      test('duplicate key resets retry_count to 0', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{}',
        );
        await store.incrementRetry('key-1');
        await store.incrementRetry('key-1');

        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{}',
        );

        final pending = await store.dequeueAll();
        expect(pending[0].retryCount, 0);
      });
    });

    group('generateIdempotencyKey', () {
      test('generates keys with correct format', () async {
        final key = store.generateIdempotencyKey(
          roundId: 'round-abc',
          operation: RoundSyncOperation.updateHoleScore,
        );

        expect(key, startsWith('round_'));
        expect(key, contains('_updateHoleScore_'));
        expect(key.split('_').length, 4);
      });

      test('generates unique keys for same round + operation', () async {
        final key1 = store.generateIdempotencyKey(
          roundId: 'round-1',
          operation: RoundSyncOperation.startRound,
        );
        await Future.delayed(const Duration(milliseconds: 1));
        final key2 = store.generateIdempotencyKey(
          roundId: 'round-1',
          operation: RoundSyncOperation.startRound,
        );

        expect(key1, isNot(key2));
      });
    });

    group('QueuedRoundUpdate payloadMap', () {
      test('payloadMap parses JSON payload correctly', () async {
        await store.enqueueRoundOp(
          idempotencyKey: 'key-1',
          operation: RoundSyncOperation.startRound,
          roundId: 'round-1',
          payload: '{"courseId":42,"courseName":"Bethpage Black"}',
        );

        final pending = await store.dequeueAll();
        final payload = pending[0].payloadMap;

        expect(payload['courseId'], 42);
        expect(payload['courseName'], 'Bethpage Black');
      });
    });
  });
}

/// TestableRoundSyncStore — injects an open database directly,
/// bypassing path_provider for test isolation.
class TestableRoundSyncStore extends RoundSyncStore {
  final Database _testDb;

  TestableRoundSyncStore(this._testDb);

  @override
  Future<Database> get database async => _testDb;

  @override
  Future<void> close() async {
    // Don't close the test database — tearDown handles it
  }
}
