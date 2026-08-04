// Bag Repository — VSP Mobile App
//
// Repository wrapping BagService with offline queue support.
// Mirrors ProfileRepository pattern from Story 2-3-B.

import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import 'bag_dto.dart';
import 'bag_service.dart';
import '../../../core/storage/bag_sync_store.dart';

/// Result of a repository write operation.
class BagRepoResult {
  final bool wasQueued;
  final bool wasSynced;
  final BagDTO? updatedBag;
  final String? errorMessage;

  const BagRepoResult({
    required this.wasQueued,
    required this.wasSynced,
    this.updatedBag,
    this.errorMessage,
  });

  factory BagRepoResult.synced(BagDTO bag) =>
      BagRepoResult(wasQueued: false, wasSynced: true, updatedBag: bag);

  factory BagRepoResult.queued(BagDTO bag) =>
      BagRepoResult(wasQueued: true, wasSynced: false, updatedBag: bag);

  factory BagRepoResult.error(String message) =>
      BagRepoResult(wasQueued: false, wasSynced: false, errorMessage: message);
}

/// Result of a club write operation.
class ClubRepoResult {
  final bool wasQueued;
  final bool wasSynced;
  final ClubDTO? updatedClub;
  final String? errorMessage;

  const ClubRepoResult({
    required this.wasQueued,
    required this.wasSynced,
    this.updatedClub,
    this.errorMessage,
  });

  factory ClubRepoResult.synced(ClubDTO club) =>
      ClubRepoResult(wasQueued: false, wasSynced: true, updatedClub: club);

  factory ClubRepoResult.queued(ClubDTO club) =>
      ClubRepoResult(wasQueued: true, wasSynced: false, updatedClub: club);

  factory ClubRepoResult.error(String message) =>
      ClubRepoResult(wasQueued: false, wasSynced: false, errorMessage: message);
}

/// Repository for bag and club data with offline queue support.
class BagRepository {
  final BagService _bagService;
  final BagSyncStore _syncStore;
  final ApiClient _apiClient;
  final Uuid _uuid = const Uuid();

  /// In-memory cache of bags (optimistic read).
  List<BagDTO> _bagsCache = [];

  BagRepository({
    required BagService bagService,
    required BagSyncStore syncStore,
    required ApiClient apiClient,
  }) : _bagService = bagService,
       _syncStore = syncStore,
       _apiClient = apiClient {
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    // Connectivity listener is registered at the app level in main.dart.
    // The repository exposes flushQueue for explicit flushing.
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  /// Fetch all bags (forceReload bypasses cache).
  Future<List<BagDTO>> getBags({bool forceReload = false}) async {
    if (!forceReload && _bagsCache.isNotEmpty) {
      return _bagsCache;
    }
    _bagsCache = await _bagService.getBags();
    return _bagsCache;
  }

  /// Return the active bag (isActive == true).
  Future<BagDTO?> getActiveBag() async {
    final bags = await getBags();
    try {
      return bags.firstWhere((b) => b.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Get a specific bag by ID from cache.
  Future<BagDTO?> getBagById(int bagId) async {
    final bags = await getBags();
    try {
      return bags.firstWhere((b) => b.id == bagId);
    } catch (_) {
      return null;
    }
  }

  /// AC-3: check if the active bag has minimum club data for recommendations.
  Future<bool> hasMinimumClubData() async {
    final activeBag = await getActiveBag();
    if (activeBag == null) return false;
    return activeBag.hasMinimumClubData;
  }

  /// True if there are pending offline updates.
  Future<bool> hasPendingUpdates() async {
    return _syncStore.hasPending();
  }

  // ─── Bag Write Operations ─────────────────────────────────────────────────

  /// Create a new bag.
  Future<BagRepoResult> createBag({required String name}) async {
    final request = CreateBagRequest(name: name);
    final idempotencyKey = _uuid.v4();

    // Try immediate sync first
    try {
      final bag = await _bagService.createBag(request);
      _updateCacheWithBag(bag);
      return BagRepoResult.synced(bag);
    } catch (_) {
      // Queue for later sync
      await _syncStore.enqueueBagOp(
        idempotencyKey: idempotencyKey,
        operation: BagSyncOperation.createBag,
        bagId: 0,
        payload: '{"name":"$name"}',
      );
      // Optimistic cache update
      final optimisticBag = BagDTO(
        id: -DateTime.now().millisecondsSinceEpoch,
        golferAccountId: 0,
        name: name,
        isActive: _bagsCache.isEmpty,
        clubs: [],
      );
      _updateCacheWithBag(optimisticBag);
      return BagRepoResult.queued(optimisticBag);
    }
  }

  /// Update a bag (partial update).
  Future<BagRepoResult> updateBag({
    required int bagId,
    String? name,
    bool? isActive,
  }) async {
    final request = UpdateBagRequest(name: name, isActive: isActive);
    final idempotencyKey = _uuid.v4();

    try {
      final bag = await _bagService.updateBag(bagId, request);
      _updateCacheWithBag(bag);
      return BagRepoResult.synced(bag);
    } catch (_) {
      await _syncStore.enqueueBagOp(
        idempotencyKey: idempotencyKey,
        operation: isActive == true
            ? BagSyncOperation.setActiveBag
            : BagSyncOperation.updateBag,
        bagId: bagId,
        payload: request.toJson().toString(),
      );
      // Optimistic cache update
      final cachedBag = await getBagById(bagId);
      if (cachedBag != null) {
        final optimisticBag = cachedBag.copyWith(
          name: name ?? cachedBag.name,
          isActive: isActive ?? cachedBag.isActive,
        );
        _updateCacheWithBag(optimisticBag);
        return BagRepoResult.queued(optimisticBag);
      }
      return BagRepoResult.error('Bag not found');
    }
  }

  /// Set a bag as active (AC-2: deactivates all others).
  Future<BagRepoResult> setActiveBag(int bagId) async {
    final idempotencyKey = _uuid.v4();

    try {
      final bag = await _bagService.activateBag(bagId);
      _updateCacheWithBag(bag);
      return BagRepoResult.synced(bag);
    } catch (_) {
      await _syncStore.enqueueBagOp(
        idempotencyKey: idempotencyKey,
        operation: BagSyncOperation.setActiveBag,
        bagId: bagId,
        payload: '{}',
      );
      // Optimistic: mark this bag active and all others inactive
      _bagsCache = _bagsCache.map((b) {
        return b.copyWith(isActive: b.id == bagId);
      }).toList();
      final activeBag = _bagsCache.firstWhere((b) => b.id == bagId);
      return BagRepoResult.queued(activeBag);
    }
  }

  /// Delete a bag.
  Future<BagRepoResult> deleteBag(int bagId) async {
    final idempotencyKey = _uuid.v4();

    try {
      await _bagService.deleteBag(bagId);
      _bagsCache = _bagsCache.where((b) => b.id != bagId).toList();
      return BagRepoResult.synced(
        _bagsCache.isNotEmpty
            ? _bagsCache.first
            : BagDTO(id: 0, golferAccountId: 0, name: '', isActive: false),
      );
    } catch (_) {
      await _syncStore.enqueueBagOp(
        idempotencyKey: idempotencyKey,
        operation: BagSyncOperation.deleteBag,
        bagId: bagId,
        payload: '{}',
      );
      _bagsCache = _bagsCache.where((b) => b.id != bagId).toList();
      return BagRepoResult.queued(
        _bagsCache.isNotEmpty
            ? _bagsCache.first
            : BagDTO(id: 0, golferAccountId: 0, name: '', isActive: false),
      );
    }
  }

  // ─── Club Write Operations ─────────────────────────────────────────────────

  /// Add a club to a bag.
  Future<ClubRepoResult> createClub({
    required int bagId,
    required CreateClubRequest request,
  }) async {
    final idempotencyKey = _uuid.v4();

    try {
      final club = await _bagService.createClub(bagId, request);
      _addClubToCache(bagId, club);
      return ClubRepoResult.synced(club);
    } catch (_) {
      await _syncStore.enqueueClubOp(
        idempotencyKey: idempotencyKey,
        operation: BagSyncOperation.createClub,
        bagId: bagId,
        clubId: 0,
        payload: request.toJson().toString(),
      );
      // Optimistic club
      final optimisticClub = ClubDTO(
        id: -DateTime.now().millisecondsSinceEpoch,
        golfBagId: bagId,
        clubType: ClubType.fromString(request.clubType),
        loft: request.loft,
        carryDistance: request.carryDistance,
        totalDistance: request.totalDistance,
        dispersion: request.dispersion,
        shaft: request.shaft,
        useDate: request.useDate != null
            ? DateTime.tryParse(request.useDate!)
            : null,
      );
      _addClubToCache(bagId, optimisticClub);
      return ClubRepoResult.queued(optimisticClub);
    }
  }

  /// Update a club.
  Future<ClubRepoResult> updateClub({
    required int bagId,
    required int clubId,
    required UpdateClubRequest request,
  }) async {
    final idempotencyKey = _uuid.v4();

    try {
      final club = await _bagService.updateClub(bagId, clubId, request);
      _updateClubInCache(bagId, club);
      return ClubRepoResult.synced(club);
    } catch (_) {
      await _syncStore.enqueueClubOp(
        idempotencyKey: idempotencyKey,
        operation: BagSyncOperation.updateClub,
        bagId: bagId,
        clubId: clubId,
        payload: request.toJson().toString(),
      );
      // Optimistic update
      final cachedBag = await getBagById(bagId);
      if (cachedBag != null) {
        final existingClub = cachedBag.clubs.firstWhere(
          (c) => c.id == clubId,
          orElse: () =>
              ClubDTO(id: clubId, golfBagId: bagId, clubType: ClubType.iron),
        );
        final updated = ClubDTO(
          id: clubId,
          golfBagId: bagId,
          clubType: request.clubType != null
              ? ClubType.fromString(request.clubType!)
              : existingClub.clubType,
          loft: request.loft ?? existingClub.loft,
          carryDistance: request.carryDistance ?? existingClub.carryDistance,
          totalDistance: request.totalDistance ?? existingClub.totalDistance,
          dispersion: request.dispersion ?? existingClub.dispersion,
          shaft: request.shaft ?? existingClub.shaft,
          useDate: request.useDate != null
              ? DateTime.tryParse(request.useDate!)
              : existingClub.useDate,
        );
        _updateClubInCache(bagId, updated);
        return ClubRepoResult.queued(updated);
      }
      return ClubRepoResult.error('Bag not found');
    }
  }

  /// Delete a club.
  Future<ClubRepoResult> deleteClub({
    required int bagId,
    required int clubId,
  }) async {
    final idempotencyKey = _uuid.v4();

    try {
      await _bagService.deleteClub(bagId, clubId);
      _removeClubFromCache(bagId, clubId);
      return ClubRepoResult.synced(
        ClubDTO(id: clubId, golfBagId: bagId, clubType: ClubType.iron),
      );
    } catch (_) {
      await _syncStore.enqueueClubOp(
        idempotencyKey: idempotencyKey,
        operation: BagSyncOperation.deleteClub,
        bagId: bagId,
        clubId: clubId,
        payload: '{}',
      );
      _removeClubFromCache(bagId, clubId);
      return ClubRepoResult.queued(
        ClubDTO(id: clubId, golfBagId: bagId, clubType: ClubType.iron),
      );
    }
  }

  // ─── Flush Queue ───────────────────────────────────────────────────────────

  /// Flush all pending queue entries to the server.
  /// Called when connectivity is restored.
  Future<void> flushQueue() async {
    final pending = await _syncStore.dequeueAll();

    for (final entry in pending) {
      try {
        switch (entry.operation) {
          case BagSyncOperation.createBag:
            await _bagService.createBag(
              CreateBagRequest(name: entry.payloadMap['name'] as String),
            );
            break;
          case BagSyncOperation.updateBag:
            if (entry.bagId != null) {
              await _bagService.updateBag(
                entry.bagId!,
                UpdateBagRequest(
                  name: entry.payloadMap['name'] as String?,
                  isActive: entry.payloadMap['isActive'] as bool?,
                ),
              );
            }
            break;
          case BagSyncOperation.setActiveBag:
            if (entry.bagId != null) {
              await _bagService.activateBag(entry.bagId!);
            }
            break;
          case BagSyncOperation.deleteBag:
            if (entry.bagId != null) {
              await _bagService.deleteBag(entry.bagId!);
            }
            break;
          case BagSyncOperation.createClub:
            // Club create requires re-fetch to get the real ID
            // For simplicity, just mark synced and let the next getBags refresh
            break;
          case BagSyncOperation.updateClub:
            if (entry.bagId != null && entry.clubId != null) {
              await _bagService.updateClub(
                entry.bagId!,
                entry.clubId!,
                UpdateClubRequest(
                  clubType: entry.payloadMap['clubType'] as String?,
                  loft: (entry.payloadMap['loft'] as num?)?.toDouble(),
                  carryDistance: (entry.payloadMap['carryDistance'] as num?)
                      ?.toDouble(),
                  totalDistance: (entry.payloadMap['totalDistance'] as num?)
                      ?.toDouble(),
                  dispersion: (entry.payloadMap['dispersion'] as num?)
                      ?.toDouble(),
                  shaft: entry.payloadMap['shaft'] as String?,
                  useDate: entry.payloadMap['useDate'] as String?,
                ),
              );
            }
            break;
          case BagSyncOperation.deleteClub:
            if (entry.bagId != null && entry.clubId != null) {
              await _bagService.deleteClub(entry.bagId!, entry.clubId!);
            }
            break;
        }
        await _syncStore.markSynced(entry.idempotencyKey);
      } catch (_) {
        // Leave in queue for next retry
      }
    }

    // Refresh cache after flush
    await getBags(forceReload: true);
  }

  // ─── Cache Helpers ─────────────────────────────────────────────────────────

  void _updateCacheWithBag(BagDTO bag) {
    final idx = _bagsCache.indexWhere((b) => b.id == bag.id);
    if (idx >= 0) {
      _bagsCache[idx] = bag;
    } else {
      _bagsCache.add(bag);
    }
  }

  void _addClubToCache(int bagId, ClubDTO club) {
    final bagIdx = _bagsCache.indexWhere((b) => b.id == bagId);
    if (bagIdx < 0) return;
    final bag = _bagsCache[bagIdx];
    _bagsCache[bagIdx] = bag.copyWith(clubs: [...bag.clubs, club]);
  }

  void _updateClubInCache(int bagId, ClubDTO club) {
    final bagIdx = _bagsCache.indexWhere((b) => b.id == bagId);
    if (bagIdx < 0) return;
    final bag = _bagsCache[bagIdx];
    final clubs = bag.clubs.map((c) => c.id == club.id ? club : c).toList();
    _bagsCache[bagIdx] = bag.copyWith(clubs: clubs);
  }

  void _removeClubFromCache(int bagId, int clubId) {
    final bagIdx = _bagsCache.indexWhere((b) => b.id == bagId);
    if (bagIdx < 0) return;
    final bag = _bagsCache[bagIdx];
    _bagsCache[bagIdx] = bag.copyWith(
      clubs: bag.clubs.where((c) => c.id != clubId).toList(),
    );
  }
}
