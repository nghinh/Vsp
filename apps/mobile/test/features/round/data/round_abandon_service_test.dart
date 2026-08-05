// Tests for RoundAbandonService — POST /rounds/{id}/abandon + local mirror.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/core/storage/round_sync_store.dart';
import 'package:vsp_mobile/data/api/round_api.dart';
import 'package:vsp_mobile/data/repositories/package_manifest_repository.dart';
import 'package:vsp_mobile/data/repositories/round_repository.dart';
import 'package:vsp_mobile/data/services/active_round_guard.dart';
import 'package:vsp_mobile/domain/models/round.dart';
import 'package:vsp_mobile/domain/models/round_sync_operation.dart';
import 'package:vsp_mobile/features/round/data/round_abandon_service.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

/// In-memory stand-in for the SQLite round store.
class _FakeRoundRepository extends RoundRepository {
  _FakeRoundRepository({this.stored});

  Round? stored;
  final List<Round> updates = [];

  @override
  Future<Round?> getRound(String id) async => stored?.id == id ? stored : null;

  @override
  Future<void> updateRound(Round round) async {
    updates.add(round);
    stored = round;
  }
}

/// Records guard releases without touching the guard's database.
class _FakeActiveRoundGuard extends ActiveRoundGuard {
  _FakeActiveRoundGuard()
    : super(manifestRepo: PackageManifestRepository());

  final List<int> released = [];

  @override
  Future<void> recordRoundEnd(int courseId) async => released.add(courseId);
}

/// Deterministic idempotency keys.
class _FakeSyncStore extends RoundSyncStore {
  final List<String> requested = [];

  @override
  String generateIdempotencyKey({
    required String roundId,
    required RoundSyncOperation operation,
  }) {
    requested.add('$roundId:${operation.name}');
    return 'key-$roundId';
  }
}

// ─── Fixtures ───────────────────────────────────────────────────────────────

Round _round({RoundStatus status = RoundStatus.inProgress}) {
  final now = DateTime(2026, 8, 5, 7);
  return Round(
    id: 'round-1',
    courseId: 42,
    courseName: 'Sân Golf Long Thành',
    status: status,
    startedAt: now,
    packageVersion: '',
    createdAt: now,
    updatedAt: now,
  );
}

RoundApi _apiReturning(
  int statusCode, {
  void Function(http.Request)? onRequest,
}) {
  final client = MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      jsonEncode({
        'id': 'round-1',
        'courseId': 42,
        'status': 'ABANDONED',
        'startedAt': '2026-08-05T00:00:00Z',
        'endedAt': '2026-08-05T02:00:00Z',
      }),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
  return RoundApi(apiClient: ApiClient(httpClient: client));
}

void main() {
  group('RoundAbandonService', () {
    test('posts to the abandon endpoint with an idempotency key', () async {
      final requests = <http.Request>[];
      final syncStore = _FakeSyncStore();
      final service = RoundAbandonService(
        api: _apiReturning(200, onRequest: requests.add),
        syncStore: syncStore,
        localRounds: _FakeRoundRepository(),
        guard: _FakeActiveRoundGuard(),
      );

      final outcome = await service.abandon(_round());

      expect(outcome, RoundAbandonOutcome.abandoned);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/rounds/round-1/abandon');
      expect(requests.single.headers['Idempotency-Key'], 'key-round-1');
      expect(syncStore.requested, ['round-1:endRound']);
    });

    test('mirrors the abandon locally and releases the package guard',
        () async {
      final local = _FakeRoundRepository(stored: _round());
      final guard = _FakeActiveRoundGuard();
      final service = RoundAbandonService(
        api: _apiReturning(200),
        syncStore: _FakeSyncStore(),
        localRounds: local,
        guard: guard,
      );

      await service.abandon(_round());

      expect(local.updates, hasLength(1));
      expect(local.updates.single.status, RoundStatus.abandoned);
      expect(local.updates.single.endedAt, isNotNull);
      expect(guard.released, [42]);
    });

    test('reports failure and changes nothing when the server refuses',
        () async {
      final local = _FakeRoundRepository(stored: _round());
      final guard = _FakeActiveRoundGuard();
      final service = RoundAbandonService(
        api: _apiReturning(409),
        syncStore: _FakeSyncStore(),
        localRounds: local,
        guard: guard,
      );

      final outcome = await service.abandon(_round());

      // Honest failure: the list is rebuilt from GET /rounds, so a local-only
      // abandon would reappear as in-progress on the next refresh.
      expect(outcome, RoundAbandonOutcome.failed);
      expect(local.updates, isEmpty);
      expect(guard.released, isEmpty);
    });

    test('still succeeds when there is no local round row', () async {
      final local = _FakeRoundRepository(); // nothing stored
      final guard = _FakeActiveRoundGuard();
      final service = RoundAbandonService(
        api: _apiReturning(200),
        syncStore: _FakeSyncStore(),
        localRounds: local,
        guard: guard,
      );

      expect(
        await service.abandon(_round()),
        RoundAbandonOutcome.abandoned,
      );
      expect(local.updates, isEmpty);
      expect(guard.released, [42]);
    });
  });
}
