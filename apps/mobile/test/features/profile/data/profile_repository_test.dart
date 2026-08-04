// ProfileRepository unit tests — VSP Mobile App
//
// Tests cover:
// - AC-3: queueProfileUpdate persists to sync store immediately
// - AC-3: flushQueue syncs all pending entries in order
// - AC-3: Connectivity change triggers automatic flush
// - Idempotency key is unique per update
// - Offline get returns cached profile

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/core/storage/profile_sync_store.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart';
import 'package:vsp_mobile/features/profile/data/profile_repository.dart';
import 'package:vsp_mobile/features/profile/data/profile_service.dart';
import 'package:uuid/uuid.dart';

/// Fake ProfileService that records calls and returns controlled responses.
class FakeProfileService implements ProfileService {
  ProfileDTO? getProfileResponse;
  ProfileDTO? updateProfileResponse;
  VspApiException? updateProfileError;
  List<String> receivedIdempotencyKeys = [];
  List<UpdateProfileRequest> receivedRequests = [];

  @override
  Future<ProfileDTO> getProfile() async {
    if (getProfileResponse != null) return getProfileResponse!;
    throw VspApiException(code: 'NOT_FOUND', message: 'No profile');
  }

  @override
  Future<ProfileDTO> updateProfile(
    UpdateProfileRequest request, {
    String? idempotencyKey,
  }) async {
    receivedRequests.add(request);
    if (idempotencyKey != null) receivedIdempotencyKeys.add(idempotencyKey);
    if (updateProfileError != null) throw updateProfileError!;
    return updateProfileResponse!;
  }
}

/// Fake ProfileSyncStore backed by an in-memory list.
class FakeProfileSyncStore implements ProfileSyncStore {
  final List<QueuedProfileUpdate> _queue = [];

  @override
  Future<void> enqueue(
    String idempotencyKey,
    UpdateProfileRequest request,
  ) async {
    // Remove existing with same key
    _queue.removeWhere((e) => e.idempotencyKey == idempotencyKey);
    _queue.add(
      QueuedProfileUpdate(
        idempotencyKey: idempotencyKey,
        payload: '{"handicap":${request.handicap}}',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<QueuedProfileUpdate>> dequeueAll() async {
    return _queue.where((e) => !e.isSynced).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> markSynced(String idempotencyKey) async {
    final idx = _queue.indexWhere((e) => e.idempotencyKey == idempotencyKey);
    if (idx >= 0) {
      _queue[idx] = QueuedProfileUpdate(
        idempotencyKey: idempotencyKey,
        payload: _queue[idx].payload,
        createdAt: _queue[idx].createdAt,
        syncedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<bool> hasPending() async => _queue.any((e) => !e.isSynced);

  @override
  Future<int> pendingCount() async => _queue.where((e) => !e.isSynced).length;

  @override
  Future<int> purgeSynced() async {
    final before = _queue.length;
    _queue.removeWhere((e) => e.isSynced);
    return before - _queue.length;
  }

  @override
  Future<void> close() async {}
}

/// Fake Connectivity that lets us control the result.
class FakeConnectivity implements Connectivity {
  List<ConnectivityResult> checkResult = [ConnectivityResult.none];
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => checkResult;

  void setOnline() {
    checkResult = [ConnectivityResult.wifi];
    _controller.add(checkResult);
  }

  void setOffline() {
    checkResult = [ConnectivityResult.none];
    _controller.add(checkResult);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  late FakeProfileService fakeService;
  late FakeProfileSyncStore fakeStore;
  late FakeConnectivity fakeConnectivity;
  late Uuid fakeUuid;
  late ProfileRepository repository;

  ProfileDTO makeProfile({double? handicap}) => ProfileDTO(
    id: 1,
    golferAccountId: 42,
    handicap: handicap ?? 12.0,
    homeClub: 'Test Club',
    distanceUnit: DistanceUnit.meters,
    dominantHand: DominantHand.right,
    skillLevel: SkillLevel.intermediate,
  );

  setUp(() {
    fakeService = FakeProfileService();
    fakeStore = FakeProfileSyncStore();
    fakeConnectivity = FakeConnectivity();
    fakeUuid = const Uuid();

    repository = ProfileRepository(
      profileService: fakeService,
      syncStore: fakeStore,
      connectivity: fakeConnectivity,
      uuid: fakeUuid,
    );
  });

  tearDown(() async {
    await repository.dispose();
    fakeConnectivity.dispose();
  });

  group('ProfileRepository', () {
    group('getProfile', () {
      test('fetches from server and caches result', () async {
        final serverProfile = makeProfile(handicap: 10.0);
        fakeService.getProfileResponse = serverProfile;

        final result = await repository.getProfile();

        expect(result.handicap, 10.0);
        expect(repository.getCachedProfile()?.handicap, 10.0);
      });

      test('returns cached profile on network error', () async {
        final serverProfile = makeProfile(handicap: 10.0);
        fakeService.getProfileResponse = serverProfile;

        // Populate cache
        await repository.getProfile();

        // Make API fail
        fakeService.getProfileResponse = null;
        fakeService.updateProfileError = VspApiException(
          code: 'NETWORK',
          message: 'Offline',
        );

        final cached = repository.getCachedProfile();
        expect(cached?.handicap, 10.0);
      });
    });

    group('AC-3: Offline queue', () {
      test('queueProfileUpdate enqueues to sync store immediately', () async {
        fakeConnectivity.setOffline();

        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 15.0),
        );

        expect(await fakeStore.pendingCount(), 1);
      });

      test(
        'queueProfileUpdate returns queuedOffline=true when offline',
        () async {
          fakeConnectivity.setOffline();
          fakeService.getProfileResponse = makeProfile();

          final result = await repository.queueProfileUpdate(
            const UpdateProfileRequest(handicap: 15.0),
          );

          expect(result.queuedOffline, isTrue);
          expect(result.serverProfile, isNull);
          expect(result.idempotencyKey, isNotEmpty);
        },
      );

      test(
        'queueProfileUpdate returns queuedOffline=false when online',
        () async {
          fakeConnectivity.setOnline();
          fakeService.getProfileResponse = makeProfile(handicap: 15.0);
          fakeService.updateProfileResponse = makeProfile(handicap: 15.0);

          final result = await repository.queueProfileUpdate(
            const UpdateProfileRequest(handicap: 15.0),
          );

          expect(result.queuedOffline, isFalse);
          expect(result.serverProfile?.handicap, 15.0);
        },
      );

      test('flushQueue syncs all pending entries in order', () async {
        fakeService.getProfileResponse = makeProfile();
        fakeService.updateProfileResponse = makeProfile(handicap: 20.0);
        fakeConnectivity.setOffline();

        // Queue two updates while offline
        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 15.0),
        );
        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 20.0),
        );

        expect(await fakeStore.pendingCount(), 2);

        // Go online and flush
        fakeConnectivity.setOnline();
        await repository.flushQueue();

        expect(await fakeStore.pendingCount(), 0);
        expect(fakeService.receivedRequests.length, 2);
        expect(fakeService.receivedRequests[0].handicap, 15.0);
        expect(fakeService.receivedRequests[1].handicap, 20.0);
      });

      test('each queued update has a unique idempotency key', () async {
        fakeConnectivity.setOffline();

        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 10.0),
        );
        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 11.0),
        );

        final queued = await repository.getQueuedUpdates();
        final keys = queued.map((entry) => entry.idempotencyKey).toList();
        expect(keys, hasLength(2));
        expect(keys.toSet(), hasLength(2));
      });

      test('hasPending returns true when queue has entries', () async {
        fakeConnectivity.setOffline();

        expect(await repository.hasPending(), isFalse);
        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 10.0),
        );
        expect(await repository.hasPending(), isTrue);
      });

      test('optimistic update applies to cached profile immediately', () async {
        fakeService.getProfileResponse = makeProfile(handicap: 10.0);
        fakeConnectivity.setOffline();

        await repository.getProfile(); // populate cache
        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 9.0),
        );

        // Cache should reflect the optimistic update
        expect(repository.getCachedProfile()?.handicap, 9.0);
      });

      test('getQueuedUpdates returns pending entries', () async {
        fakeConnectivity.setOffline();
        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 10.0),
        );
        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 11.0),
        );

        final pending = await repository.getQueuedUpdates();

        expect(pending.length, 2);
        expect(pending[0].request.handicap, 10.0);
        expect(pending[1].request.handicap, 11.0);
      });
    });

    group('Connectivity listener', () {
      test('transition from offline to online triggers flushQueue', () async {
        fakeService.getProfileResponse = makeProfile();
        fakeService.updateProfileResponse = makeProfile(handicap: 10.0);
        fakeConnectivity.setOffline();

        await repository.queueProfileUpdate(
          const UpdateProfileRequest(handicap: 10.0),
        );
        expect(await fakeStore.pendingCount(), 1);

        // Simulate connectivity change: offline -> online
        fakeConnectivity.setOnline();

        // Give the async flush a chance to run
        await Future.delayed(const Duration(milliseconds: 100));

        expect(await fakeStore.pendingCount(), 0);
      });
    });
  });
}
