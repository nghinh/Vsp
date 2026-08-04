// Profile Repository — VSP Mobile App
//
// Orchestrates profile service calls and offline queue persistence.
// Single source of truth for profile state from the mobile app perspective.
//
// Offline strategy (per architecture.md §8.3):
//   1. All writes are persisted to the local SQLite queue first (durability).
//   2. A sync worker flushes the queue when connectivity is available.
//   3. Idempotency keys ensure safe retry without server-side duplication.
//   4. Conflict policy: latest client edit wins (server accepts by timestamp).
//
// Flush-on-reconnect:
//   Connectivity changes are monitored via connectivity_plus Stream.
//   When the device transitions from offline to online, flushQueue() is called.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/profile_sync_store.dart';
import 'profile_dto.dart';
import 'profile_service.dart';

/// Result of a profile update — includes server response and queue status.
class ProfileUpdateResult {
  /// Server response (null if offline-queued).
  final ProfileDTO? serverProfile;

  /// True if the update was queued for later sync (offline).
  final bool queuedOffline;

  /// The idempotency key assigned to this update.
  final String idempotencyKey;

  const ProfileUpdateResult({
    this.serverProfile,
    required this.queuedOffline,
    required this.idempotencyKey,
  });
}

/// Profile repository — coordinates service calls, local cache, and sync queue.
class ProfileRepository {
  final ProfileService _profileService;
  final ProfileSyncStore _syncStore;
  final Connectivity _connectivity;
  final Uuid _uuid;

  /// Last known profile from server (in-memory cache, refreshed on getProfile).
  ProfileDTO? _cachedProfile;

  /// Stream subscription for connectivity changes.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// True while flushQueue() is running (prevent concurrent flushes).
  bool _isFlushing = false;

  ProfileRepository({
    required ProfileService profileService,
    required ProfileSyncStore syncStore,
    Connectivity? connectivity,
    Uuid? uuid,
  }) : _profileService = profileService,
       _syncStore = syncStore,
       _connectivity = connectivity ?? Connectivity(),
       _uuid = uuid ?? const Uuid() {
    _startConnectivityListener();
  }

  // ─── Connectivity Listener ─────────────────────────────────────────────────

  /// Start listening to connectivity changes — flush queue on reconnect.
  void _startConnectivityListener() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        flushQueue();
      }
    });
  }

  // ─── Get Profile ────────────────────────────────────────────────────────────

  /// Fetch profile from server, update cache.
  /// Returns cached profile if network call fails.
  Future<ProfileDTO> getProfile() async {
    try {
      final profile = await _profileService.getProfile();
      _cachedProfile = profile;
      return profile;
    } on VspApiException {
      // Network error — return cached profile if available
      if (_cachedProfile != null) return _cachedProfile!;
      rethrow;
    }
  }

  /// Get the cached profile without a network call.
  /// Returns null if no cache exists.
  ProfileDTO? getCachedProfile() => _cachedProfile;

  // ─── Queue Profile Update (offline-capable) ────────────────────────────────

  /// Queue a profile update for sync.
  ///
  /// The update is persisted to SQLite immediately so it survives app restarts.
  /// If the device is online, the queue is flushed right away.
  /// If offline, the update waits in the queue until connectivity is restored.
  ///
  /// Returns a [ProfileUpdateResult] with the idempotency key and whether
  /// the update was queued offline (vs. immediately synced).
  Future<ProfileUpdateResult> queueProfileUpdate(
    UpdateProfileRequest request,
  ) async {
    final idempotencyKey = _uuid.v4();

    // Always persist to queue first (durability before sync)
    await _syncStore.enqueue(idempotencyKey, request);

    // Optimistically update local cache so UI reflects the change immediately
    _applyOptimisticUpdate(request);

    // Try to flush immediately if online
    final isOnline = await _isOnline();
    if (isOnline) {
      await _flushOne(idempotencyKey, request);
      return ProfileUpdateResult(
        serverProfile: _cachedProfile,
        queuedOffline: false,
        idempotencyKey: idempotencyKey,
      );
    }

    // Offline — queued for later
    return ProfileUpdateResult(
      serverProfile: null,
      queuedOffline: true,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Apply an optimistic update to the local cache (no server round-trip).
  void _applyOptimisticUpdate(UpdateProfileRequest request) {
    if (_cachedProfile == null) return;
    _cachedProfile = ProfileDTO(
      id: _cachedProfile!.id,
      golferAccountId: _cachedProfile!.golferAccountId,
      handicap: request.handicap ?? _cachedProfile!.handicap,
      homeClub: request.homeClub ?? _cachedProfile!.homeClub,
      distanceUnit: request.distanceUnit != null
          ? DistanceUnit.fromString(request.distanceUnit!)
          : _cachedProfile!.distanceUnit,
      dominantHand: request.dominantHand != null
          ? DominantHand.fromString(request.dominantHand!)
          : _cachedProfile!.dominantHand,
      skillLevel: request.skillLevel != null
          ? SkillLevel.fromString(request.skillLevel!)
          : _cachedProfile!.skillLevel,
      targetScore: request.targetScore ?? _cachedProfile!.targetScore,
      driverDistance: request.driverDistance ?? _cachedProfile!.driverDistance,
      swingSpeed: request.swingSpeed ?? _cachedProfile!.swingSpeed,
      gender: request.gender != null
          ? Gender.fromString(request.gender!)
          : _cachedProfile!.gender,
      birthYear: request.birthYear ?? _cachedProfile!.birthYear,
      country: request.country ?? _cachedProfile!.country,
      imageUrl: request.imageUrl ?? _cachedProfile!.imageUrl,
      createdAt: _cachedProfile!.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // ─── Flush Queue ───────────────────────────────────────────────────────────

  /// Flush all pending queue entries to the server in creation order.
  ///
  /// Called automatically on connectivity change (offline → online).
  /// Also callable manually (e.g., user-initiated sync).
  ///
  /// Silently skips entries that fail — they remain in the queue for retry.
  /// Concurrent calls are ignored (single flush worker).
  Future<void> flushQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      final pending = await _syncStore.dequeueAll();
      for (final entry in pending) {
        await _flushOne(entry.idempotencyKey, entry.request);
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// Flush a single queue entry to the server.
  Future<void> _flushOne(
    String idempotencyKey,
    UpdateProfileRequest request,
  ) async {
    try {
      final updated = await _profileService.updateProfile(
        request,
        idempotencyKey: idempotencyKey,
      );
      _cachedProfile = updated;
      await _syncStore.markSynced(idempotencyKey);
    } on VspApiException {
      // Sync failed — leave in queue for next flush attempt
      // Do not mark as synced; it will be retried
    }
  }

  // ─── Queue Queries ─────────────────────────────────────────────────────────

  /// Return all pending (not yet synced) queue entries.
  Future<List<QueuedProfileUpdate>> getQueuedUpdates() {
    return _syncStore.dequeueAll();
  }

  /// True if there are pending updates waiting to sync.
  Future<bool> hasPending() {
    return _syncStore.hasPending();
  }

  /// Number of pending updates in the queue.
  Future<int> pendingCount() {
    return _syncStore.pendingCount();
  }

  // ─── Connectivity ───────────────────────────────────────────────────────────

  Future<bool> _isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  /// Dispose resources — call when profile feature is destroyed.
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _syncStore.close();
  }
}
