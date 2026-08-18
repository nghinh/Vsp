// The round queue gets carried.
//
// `RoundSyncStore.dequeueAll()` had no callers in the app. Four places write
// to that queue — the scorecard's finish, both branches of
// RoundCompletionBloc, and RoundStateService — and the comment beside the
// scorecard's catch block reads "queue the completion so it can be retried".
// Nothing retried it.
//
// The consequence is not a delay, it is a disappearance: round history is read
// from the server (`RoundHistoryRepository` calls GET /rounds and nothing
// else), so a round the server never learned about is missing from the list
// rather than marked unsynced. A golfer who played somewhere with no signal
// came home to a history without that afternoon in it.
//
// Verified against the live API on 18/8/2026: completing a round id the server
// never issued answers 404 VSP-ERR-ROUND-001. So the postman was only half the
// problem — these tests also pin the address, `clientRoundId`.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/application/sync/round_queue_sync.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/core/storage/round_sync_store.dart';
import 'package:vsp_mobile/data/api/round_api.dart';
import 'package:vsp_mobile/domain/models/queued_round_update.dart';
import 'package:vsp_mobile/domain/models/round_sync_operation.dart';

/// What the drainer asked the API to do, in order.
class _FakeApi implements RoundApi {
  final List<String> calls = [];
  final Map<String, Object?> lastCreate = {};

  /// Thrown on the next call, once.
  Object? failWith;

  RoundApiModel _model(String id) => RoundApiModel(
    id: id,
    courseId: 1351,
    status: 'IN_PROGRESS',
    startedAt: DateTime.utc(2026, 8, 18),
  );

  void _maybeThrow() {
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }
  }

  @override
  Future<RoundApiModel> createRound({
    required int courseId,
    List<int> segmentCourseIds = const [],
    required String idempotencyKey,
    String? clientRoundId,
    DateTime? startTime,
    int? packageId,
    bool cartRequested = false,
    String? tournamentPolicyId,
    String? tournamentId,
    String? format,
    bool? countsTowardHandicap,
  }) async {
    _maybeThrow();
    calls.add('create:$clientRoundId');
    lastCreate
      ..clear()
      ..addAll({
        'courseId': courseId,
        'clientRoundId': clientRoundId,
        'segmentCourseIds': segmentCourseIds,
        'format': format,
        'countsTowardHandicap': countsTowardHandicap,
        'packageId': packageId,
      });
    return _model(clientRoundId ?? 'server-made-one-up');
  }

  @override
  Future<RoundApiModel> completeRound({
    required String roundId,
    required String idempotencyKey,
  }) async {
    _maybeThrow();
    calls.add('complete:$roundId');
    return _model(roundId);
  }

  @override
  Future<RoundApiModel> abandonRound({
    required String roundId,
    required String idempotencyKey,
  }) async {
    _maybeThrow();
    calls.add('abandon:$roundId');
    return _model(roundId);
  }
}

/// The queue, in memory.
class _FakeStore implements RoundSyncStore {
  _FakeStore(this._entries);

  final List<QueuedRoundUpdate> _entries;
  final Set<String> synced = {};
  final List<String> retried = [];

  List<QueuedRoundUpdate> get stillPending =>
      _entries.where((e) => !synced.contains(e.idempotencyKey)).toList();

  @override
  Future<List<QueuedRoundUpdate>> dequeueAll() async => stillPending;

  @override
  Future<void> markSynced(String idempotencyKey) async {
    synced.add(idempotencyKey);
  }

  @override
  Future<void> incrementRetry(String idempotencyKey) async {
    retried.add(idempotencyKey);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

QueuedRoundUpdate _entry({
  required String key,
  required RoundSyncOperation operation,
  required String roundId,
  String payload = '{}',
  int minutesAgo = 0,
}) => QueuedRoundUpdate(
  idempotencyKey: key,
  operation: operation,
  roundId: roundId,
  payload: payload,
  createdAt: DateTime.utc(2026, 8, 18, 9).subtract(Duration(minutes: minutesAgo)),
);

void main() {
  const roundId = '11111111-2222-3333-4444-555555555555';

  test('a queued finish is sent, and the queue entry is closed', () async {
    final api = _FakeApi();
    final store = _FakeStore([
      _entry(key: 'k1', operation: RoundSyncOperation.endRound, roundId: roundId),
    ]);

    final sent = await RoundQueueSync(api: api, store: store).drain();

    expect(sent, 1);
    expect(api.calls, ['complete:$roundId']);
    expect(store.stillPending, isEmpty);
  });

  test('a queued start names the round the phone is already using', () async {
    // The whole point. Without clientRoundId the server issues its own id and
    // the finish below is addressed to a round nobody has heard of.
    final api = _FakeApi();
    final store = _FakeStore([
      _entry(
        key: 'k1',
        operation: RoundSyncOperation.startRound,
        roundId: roundId,
        payload: encodeStartRoundPayload(
          courseId: 1351,
          segmentCourseIds: const [1351, 1353],
          startTime: DateTime.utc(2026, 8, 18, 7),
          packageId: 42,
          format: 'CASUAL',
          countsTowardHandicap: true,
        ),
      ),
    ]);

    await RoundQueueSync(api: api, store: store).drain();

    expect(api.lastCreate['clientRoundId'], roundId);
    expect(api.lastCreate['courseId'], 1351);
    expect(api.lastCreate['segmentCourseIds'], [1351, 1353]);
    expect(api.lastCreate['format'], 'CASUAL');
    expect(api.lastCreate['countsTowardHandicap'], true);
    expect(api.lastCreate['packageId'], 42);
  });

  test('the round is created before it is finished', () async {
    // A round played out of signal has both in the queue. Finishing one that
    // has not been created yet is the 404 this whole change exists to stop.
    final api = _FakeApi();
    final store = _FakeStore([
      _entry(
        key: 'k1',
        operation: RoundSyncOperation.startRound,
        roundId: roundId,
        payload: encodeStartRoundPayload(courseId: 1351),
        minutesAgo: 240,
      ),
      _entry(
        key: 'k2',
        operation: RoundSyncOperation.endRound,
        roundId: roundId,
      ),
    ]);

    await RoundQueueSync(api: api, store: store).drain();

    expect(api.calls, ['create:$roundId', 'complete:$roundId']);
  });

  test('a lost network leaves the queue alone rather than emptying it',
      () async {
    final api = _FakeApi()
      ..failWith = const VspApiException(
        code: 'NETWORK_ERROR',
        message: 'no route to host',
      );
    final store = _FakeStore([
      _entry(key: 'k1', operation: RoundSyncOperation.endRound, roundId: roundId),
      _entry(key: 'k2', operation: RoundSyncOperation.endRound, roundId: 'other'),
    ]);

    final sent = await RoundQueueSync(api: api, store: store).drain();

    expect(sent, 0);
    expect(store.stillPending.length, 2, reason: 'nothing was lost');
    expect(store.retried, ['k1']);
    expect(
      api.calls,
      isEmpty,
      reason:
          'the second entry is not tried on a connection that just refused '
          'the first',
    );
  });

  test('a score edit is left for the other queue', () async {
    // Scores travel on sync_queue, drained by SyncWorker. Marking one done
    // here would delete it from the only queue that can send it.
    final api = _FakeApi();
    final store = _FakeStore([
      _entry(
        key: 'k1',
        operation: RoundSyncOperation.updateHoleScore,
        roundId: roundId,
      ),
    ]);

    final sent = await RoundQueueSync(api: api, store: store).drain();

    expect(sent, 0);
    expect(api.calls, isEmpty);
    expect(store.stillPending.length, 1);
  });
}
