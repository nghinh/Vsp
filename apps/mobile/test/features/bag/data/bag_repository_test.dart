import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/core/storage/bag_sync_store.dart';
import 'package:vsp_mobile/features/bag/data/bag_dto.dart';
import 'package:vsp_mobile/features/bag/data/bag_repository.dart';
import 'package:vsp_mobile/features/bag/data/bag_service.dart';

class FakeBagService implements BagService {
  List<BagDTO> bags = const [];
  Object? error;

  @override
  Future<List<BagDTO>> getBags() async {
    if (error != null) throw error!;
    return bags;
  }

  @override
  Future<BagDTO> createBag(CreateBagRequest request) async => bags.first;

  @override
  Future<BagDTO> updateBag(int bagId, UpdateBagRequest request) async =>
      bags.first;

  @override
  Future<void> deleteBag(int bagId) async {}

  @override
  Future<BagDTO> activateBag(int bagId) async => bags.first;

  @override
  Future<List<ClubDTO>> getClubs(int bagId) async => bags.first.clubs;

  @override
  Future<ClubDTO> createClub(int bagId, CreateClubRequest request) async =>
      bags.first.clubs.first;

  @override
  Future<ClubDTO> updateClub(
    int bagId,
    int clubId,
    UpdateClubRequest request,
  ) async => bags.first.clubs.first;

  @override
  Future<void> deleteClub(int bagId, int clubId) async {}
}

class FakeBagSyncStore implements BagSyncStore {
  final List<QueuedBagUpdate> queue = [];

  @override
  Future<void> enqueueBagOp({
    required String idempotencyKey,
    required BagSyncOperation operation,
    required int bagId,
    String? payload,
  }) async {
    queue.add(
      QueuedBagUpdate(
        idempotencyKey: idempotencyKey,
        operation: operation,
        bagId: bagId,
        payload: payload ?? '{}',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> enqueueClubOp({
    required String idempotencyKey,
    required BagSyncOperation operation,
    required int bagId,
    required int clubId,
    String? payload,
  }) async {
    queue.add(
      QueuedBagUpdate(
        idempotencyKey: idempotencyKey,
        operation: operation,
        bagId: bagId,
        clubId: clubId,
        payload: payload ?? '{}',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<QueuedBagUpdate>> dequeueAll() async =>
      queue.where((entry) => !entry.isSynced).toList();

  @override
  Future<void> markSynced(String idempotencyKey) async {
    queue.removeWhere((entry) => entry.idempotencyKey == idempotencyKey);
  }

  @override
  Future<bool> hasPending() async => queue.isNotEmpty;

  @override
  Future<int> pendingCount() async => queue.length;

  @override
  Future<int> purgeSynced() async => 0;

  @override
  Future<void> close() async {}
}

void main() {
  late FakeBagService service;
  late FakeBagSyncStore store;
  late BagRepository repository;

  setUp(() {
    service = FakeBagService();
    store = FakeBagSyncStore();
    repository = BagRepository(
      bagService: service,
      syncStore: store,
      apiClient: ApiClient(),
    );
  });

  test('getBags caches service response', () async {
    service.bags = const [
      BagDTO(id: 1, golferAccountId: 42, name: 'Primary', isActive: true),
    ];

    expect(await repository.getBags(), service.bags);
    service.error = StateError('network unavailable');
    expect(await repository.getBags(), service.bags);
  });

  test('getActiveBag returns active bag', () async {
    service.bags = const [
      BagDTO(id: 1, golferAccountId: 42, name: 'Spare', isActive: false),
      BagDTO(id: 2, golferAccountId: 42, name: 'Primary', isActive: true),
    ];

    expect((await repository.getActiveBag())?.id, 2);
  });

  test('failed create is queued and reflected optimistically', () async {
    service.error = StateError('offline');

    final result = await repository.createBag(name: 'Travel');

    expect(result.wasQueued, isTrue);
    expect(result.updatedBag?.name, 'Travel');
    expect(await repository.hasPendingUpdates(), isTrue);
    expect(store.queue.single.operation, BagSyncOperation.createBag);
  });
}
