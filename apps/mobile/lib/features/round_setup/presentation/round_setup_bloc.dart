// Round Setup BLoC — VSP Mobile App
//
// State management for Round Setup screen.
// Manages course/player/format/mode/bag/startHole selection,
// package validation, nearby course suggestion, and round start.
//
// Story 5.1 — Slice C: Round Creation BLoC

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../data/api/course_search_api.dart';
import '../../../data/api/round_api.dart';
import '../../../core/storage/bag_sync_store.dart';
import '../../../core/storage/secure_storage.dart';
import '../../bag/data/bag_service.dart';
import '../../bag/data/bag_repository.dart';
import '../../../core/storage/profile_sync_store.dart';
import '../../profile/data/profile_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../../data/api/course_detail_api.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../data/services/package_readiness_service.dart';
import '../../../data/services/nearby_course_service.dart';
import '../../../domain/services/location_service.dart';
import '../../../domain/models/qualified_location.dart';
import '../../../domain/models/round.dart';
import '../../../domain/models/round_config.dart';
import '../../../domain/models/round_format.dart';
import '../../../domain/models/round_mode.dart';
import '../../../domain/models/player.dart';
import '../../../domain/models/course_package_manifest.dart';
import '../../../core/storage/round_setup_store.dart';
import 'round_setup_event.dart';
import 'round_setup_state.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

ProfileRepository _defaultProfileRepository() {
  final apiClient = ApiClient();
  return ProfileRepository(
    profileService: ProfileService(apiClient: apiClient),
    syncStore: ProfileSyncStore(),
  );
}

BagRepository _defaultBagRepository() {
  final apiClient = ApiClient();
  return BagRepository(
    bagService: BagService(apiClient: apiClient),
    syncStore: BagSyncStore(),
    apiClient: apiClient,
  );
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

/// BLoC for round setup screen.
///
/// Manages:
/// - Course/layout/tee selection
/// - Player management (1-4 players)
/// - Format/mode selection
/// - Bag selection
/// - Start hole suggestion (time-based + GPS)
/// - Package offline readiness validation
/// - Nearby course suggestion with GPS + last-played fallback
/// - Round start with guard integration and local persistence
class RoundSetupBloc extends Bloc<RoundSetupEvent, RoundSetupState> {
  final PackageManifestRepository _manifestRepo;
  final RoundRepository _roundRepo;
  final ActiveRoundGuard _activeRoundGuard;
  final PackageReadinessService _packageReadinessService;
  final NearbyCourseService _nearbyCourseService;

  /// Asked for one fix, once, to suggest the courses the golfer can see from
  /// where they are standing. Null where no service was supplied — the picker
  /// then shows the catalogue, which is what it always showed.
  final LocationService? _locationService;
  final RoundSetupStore _roundSetupStore;
  final CourseSearchApi _courseSearchApi;
  final CourseDetailApi _courseDetailApi;
  final RoundApi _roundApi;
  final ProfileRepository _profileRepository;
  final BagRepository _bagRepository;
  final SecureStorage _secureStorage;
  final Uuid _uuid;

  RoundSetupBloc({
    required PackageManifestRepository manifestRepo,
    required RoundRepository roundRepo,
    required ActiveRoundGuard activeRoundGuard,
    required PackageReadinessService packageReadinessService,
    required NearbyCourseService nearbyCourseService,
    LocationService? locationService,
    required RoundSetupStore roundSetupStore,
    CourseSearchApi? courseSearchApi,
    CourseDetailApi? courseDetailApi,
    RoundApi? roundApi,
    ProfileRepository? profileRepository,
    BagRepository? bagRepository,
    SecureStorage? secureStorage,
    Uuid uuid = const Uuid(),
  }) : _manifestRepo = manifestRepo,
       _roundRepo = roundRepo,
       _activeRoundGuard = activeRoundGuard,
       _packageReadinessService = packageReadinessService,
       _nearbyCourseService = nearbyCourseService,
       _locationService = locationService,
       _roundSetupStore = roundSetupStore,
       _courseSearchApi =
           courseSearchApi ?? CourseSearchApi(apiClient: ApiClient()),
       _courseDetailApi =
           courseDetailApi ?? CourseDetailApi(apiClient: ApiClient()),
       _roundApi = roundApi ?? RoundApi(),
       _profileRepository = profileRepository ?? _defaultProfileRepository(),
       _bagRepository = bagRepository ?? _defaultBagRepository(),
       _secureStorage = secureStorage ?? SecureStorage(),
       _uuid = uuid,
       super(const RoundSetupInitial()) {
    on<LoadInitialData>(_onLoadInitialData);
    on<CourseSelected>(_onCourseSelected);
    on<LayoutSelected>(_onLayoutSelected);
    on<SecondLayoutSelected>(_onSecondLayoutSelected);
    on<TeeSelected>(_onTeeSelected);
    on<PlayerAdded>(_onPlayerAdded);
    on<PlayerRemoved>(_onPlayerRemoved);
    on<FormatChanged>(_onFormatChanged);
    on<ModeChanged>(_onModeChanged);
    on<BagChanged>(_onBagChanged);
    on<StartHoleChanged>(_onStartHoleChanged);
    on<PackageValidationRequested>(_onPackageValidationRequested);
    on<PackageWarningAcknowledged>(_onPackageWarningAcknowledged);
    on<StartRoundTapped>(_onStartRoundTapped);
    on<NearbyCoursesLoaded>(_onNearbyCoursesLoaded);
    on<LastPlayedCoursesLoaded>(_onLastPlayedCoursesLoaded);
    on<TournamentPolicySelected>(_onTournamentPolicySelected);
  }

  // ─── Initial Load ────────────────────────────────────────────────────────────

  Future<void> _onLoadInitialData(
    LoadInitialData event,
    Emitter<RoundSetupState> emit,
  ) async {
    emit(const RoundSetupLoading());

    try {
      // The signed-in golfer is the primary player. Falls back to a local
      // identity when the profile endpoint is unreachable so an offline golfer
      // can still start a round.
      final primaryPlayer = await _loadPrimaryPlayer();

      // The golfer's active bag, if they have one — no bag is a valid state.
      final activeBag = await _loadActiveBag();

      // Get suggested start hole based on time of day
      final suggestedHole = RoundSetupReady.suggestedStartHole();

      // The catalogue, so the picker always has something to show — no GPS,
      // no permission, nothing within reach. Alphabetical, and labelled as
      // such: what it is not is a list of courses near anybody.
      List<NearbyCourseSuggestion> availableCourses = const [];
      try {
        final page = await _courseSearchApi.searchCourses(
          const CourseSearchParams(page: 0, size: 50),
        );
        availableCourses = page.content
            .map(
              (c) => NearbyCourseSuggestion(
                courseId: c.courseId,
                courseName: c.courseName ?? c.facilityName,
                latitude: c.latitude,
                longitude: c.longitude,
                distanceKm: c.distanceMeters != null
                    ? c.distanceMeters! / 1000
                    : null,
                packageId: null,
              ),
            )
            .toList();
      } catch (_) {
        // Non-fatal: the picker still works with recent/last-played entries.
        availableCourses = const [];
      }

      // Load last-played courses as fallback
      final lastPlayed = await _nearbyCourseService.getLastPlayedCourse();
      final recentCourses = lastPlayed != null
          ? [
              RecentCourseSuggestion(
                courseId: lastPlayed.courseId,
                courseName: lastPlayed.courseName,
                lastPlayedAt: lastPlayed.lastPlayedAt,
                packageId: lastPlayed.packageId,
              ),
            ]
          : <RecentCourseSuggestion>[];

      emit(
        RoundSetupReady(
          primaryPlayer: primaryPlayer,
          players: [primaryPlayer],
          activeBag: activeBag,
          selectedBagId: activeBag?.id,
          startHole: suggestedHole,
          allCourses: availableCourses,
          recentCourses: recentCourses,
        ),
      );

      // The golfer is usually standing at, or driving to, the course they are
      // about to play. Asked for after Ready is emitted, never before: a GPS
      // fix takes seconds it would otherwise take from the whole screen.
      unawaited(_suggestNearby());

      // Pre-select the course passed in (e.g. from the course-detail CTA) now
      // that the Ready state exists — dispatching here avoids the race where a
      // CourseSelected fired before load completes is dropped.
      if (event.initialCourseId != null && event.initialCourseName != null) {
        add(
          CourseSelected(
            courseId: event.initialCourseId!,
            courseName: event.initialCourseName!,
            packageId: event.initialPackageId,
          ),
        );
      }
    } catch (ex) {
      emit(RoundSetupError(message: AppMessages.roundSetupLoadFailed));
    }
  }

  // ─── Course Selection ─────────────────────────────────────────────────────────

  Future<void> _onCourseSelected(
    CourseSelected event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(
      currentState.copyWith(
        courseId: event.courseId,
        courseName: event.courseName,
        packageId: event.packageId,
      ),
    );

    // Load layouts and tees from manifest
    await _loadCourseOptions(event.courseId, emit);

    // Validate package readiness
    add(const PackageValidationRequested());
  }

  Future<void> _loadCourseOptions(
    int courseId,
    Emitter<RoundSetupState> emit,
  ) async {
    try {
      // The course detail endpoint is the source of truth for tee sets, hole
      // count and per-hole par. The offline manifest only pins the package
      // version, so it cannot answer those.
      final detail = await _courseDetailApi.getCourseDetail(courseId);

      final tees = detail.teeSets
          // The distance comes along. It is what the choice is actually about,
          // and it was being dropped here while the server had it all along.
          .map((t) => TeeOption(
                id: t.id,
                name: t.name,
                courseRating: t.rating,
                slopeRating: t.slope?.toDouble(),
                totalDistance: t.yardages.isEmpty
                    ? null
                    : t.yardages.values.fold<int>(0, (a, b) => a + b),
              ))
          .toList();
      // The đường this club has. A facility with one course yields one entry
      // and the picker stays hidden, exactly as before; Long Biên yields A, B
      // and C, and the golfer pairs two of them.
      // Only the ones with pars behind them. An đường whose name the club gave
      // us but whose card nobody has photographed yet reports holeCount 9 or
      // 18 all the same — the club does have that many — so offering it here
      // sends the golfer to a scorecard with nothing on it, and the promised
      // hole count is exactly why they trusted it. The scorecard screen still
      // lists them; that is where the photograph that fills them in arrives.
      final playable = detail.facilityCourses
          .where((c) => c.playable)
          .toList();
      final layouts = playable.isEmpty
          ? [
              LayoutOption(
                id: courseId,
                name: detail.facilityName,
                holeCount: detail.holesCount,
              ),
            ]
          : playable
                .map(
                  (c) => LayoutOption(
                    id: c.courseId,
                    name: c.name,
                    holeCount: c.holesCount,
                  ),
                )
                .toList();
      final holePars = {
        for (final h in detail.holes) h.holeNumber: h.par,
      };

      // Re-read the latest state rather than a snapshot captured before the
      // course was set: `_onCourseSelected` emits `courseId`/`courseName`
      // first, and basing this emit on the pre-selection snapshot would clobber
      // those fields (leaving `hasCourse` false while tees appear).
      final latest = state;
      if (latest is! RoundSetupReady) return;

      emit(
        latest.copyWith(
          layouts: layouts,
          tees: tees,
          // The đường the golfer actually picked, not the first alphabetically.
          selectedLayoutId: layouts.any((l) => l.id == courseId)
              ? courseId
              : layouts.first.id,
          clearSecondLayout: true,
          selectedTeeId: tees.isNotEmpty ? tees.first.id : null,
          holePars: holePars,
        ),
      );
    } catch (_) {
      // Course detail unavailable (offline / server error) — the golfer can
      // still start the round; the scorecard falls back to par 4 per hole.
    }
  }

  /// The signed-in golfer as the primary player.
  Future<Player> _loadPrimaryPlayer() async {
    try {
      // Identity + handicap come from the profile endpoint; the display name
      // was stored at sign-in, so it is available offline too.
      final profile = await _profileRepository.getProfile();
      final storedName = (await _secureStorage.getGolferDisplayName())?.trim();
      return Player(
        id: profile.golferAccountId.toString(),
        name: storedName != null && storedName.isNotEmpty ? storedName : 'Me',
        handicap: profile.handicap,
        isPrimary: true,
      );
    } catch (_) {
      // Offline or unauthenticated — fall back to the locally stored identity.
      final storedName = (await _secureStorage.getGolferDisplayName())?.trim();
      final storedId = await _secureStorage.getGolferId();
      return Player(
        id: storedId?.toString() ?? 'self',
        name: storedName != null && storedName.isNotEmpty ? storedName : 'Me',
        isPrimary: true,
      );
    }
  }

  /// The golfer's active bag, or null when they have none / it cannot load.
  Future<BagOption?> _loadActiveBag() async {
    try {
      final bag = await _bagRepository.getActiveBag();
      if (bag == null) return null;
      return BagOption(id: bag.id, name: bag.name, isActive: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onLayoutSelected(
    LayoutSelected event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    // Changing the first đường drops the second: A+B and B+? are different
    // rounds, and carrying the old partner over would silently keep a pairing
    // the golfer did not choose.
    emit(
      currentState.copyWith(
        selectedLayoutId: event.layoutId,
        clearSecondLayout: true,
      ),
    );
  }

  Future<void> _onSecondLayoutSelected(
    SecondLayoutSelected event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(
      event.layoutId == null
          ? currentState.copyWith(clearSecondLayout: true)
          : currentState.copyWith(selectedSecondLayoutId: event.layoutId),
    );
  }

  Future<void> _onTeeSelected(
    TeeSelected event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(currentState.copyWith(selectedTeeId: event.teeId));
  }

  // ─── Player Management ───────────────────────────────────────────────────────

  Future<void> _onPlayerAdded(
    PlayerAdded event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    if (currentState.players.length >= 4) {
      // Already at max — should not happen as UI should disable add button
      return;
    }

    final updatedPlayers = [...currentState.players, event.player];
    emit(currentState.copyWith(players: updatedPlayers));
  }

  Future<void> _onPlayerRemoved(
    PlayerRemoved event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    // Cannot remove primary player (self)
    if (event.playerId == currentState.primaryPlayer?.id) {
      return;
    }

    final updatedPlayers = currentState.players
        .where((p) => p.id != event.playerId)
        .toList();
    emit(currentState.copyWith(players: updatedPlayers));
  }

  // ─── Format / Mode ──────────────────────────────────────────────────────────

  Future<void> _onFormatChanged(
    FormatChanged event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(currentState.copyWith(format: event.format));
  }

  Future<void> _onModeChanged(
    ModeChanged event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    // MVP: only strokePlay is unlocked — ignore other modes
    if (!event.mode.isUnlocked) return;

    emit(currentState.copyWith(mode: event.mode));
  }

  // ─── Bag ────────────────────────────────────────────────────────────────────

  Future<void> _onBagChanged(
    BagChanged event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(currentState.copyWith(selectedBagId: event.bagId));
  }

  // ─── Start Hole ─────────────────────────────────────────────────────────────

  Future<void> _onStartHoleChanged(
    StartHoleChanged event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(currentState.copyWith(startHole: event.hole, holes: event.holes));
  }

  // ─── Package Validation ─────────────────────────────────────────────────────

  Future<void> _onPackageValidationRequested(
    PackageValidationRequested event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;
    if (currentState.courseId == null) return;

    try {
      final readiness = await _packageReadinessService.getOfflineReadiness(
        currentState.courseId!,
      );

      final status = _mapReadinessToStatus(readiness.reason);

      emit(
        currentState.copyWith(
          packageReadiness: PackageReadiness(
            status: status,
            reason: readiness.reason.name,
            manifestVersion: readiness.manifest?.version,
            expiresAt: readiness.expiresAt,
          ),
        ),
      );
    } catch (_) {
      // Package validation failed — treat as not checked
      emit(
        currentState.copyWith(
          packageReadiness: const PackageReadiness(
            status: PackageStatus.notChecked,
          ),
        ),
      );
    }
  }

  PackageStatus _mapReadinessToStatus(PackageReadinessReason reason) {
    switch (reason) {
      case PackageReadinessReason.ok:
        return PackageStatus.valid;
      case PackageReadinessReason.notDownloaded:
        return PackageStatus.notDownloaded;
      case PackageReadinessReason.expired:
        return PackageStatus.expired;
      case PackageReadinessReason.checksumMismatch:
        return PackageStatus.invalid;
      case PackageReadinessReason.filesMissing:
        return PackageStatus.notDownloaded;
    }
  }

  Future<void> _onPackageWarningAcknowledged(
    PackageWarningAcknowledged event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    // Record telemetry when user acknowledges warning
    if (currentState.courseId != null &&
        currentState.packageReadiness != null) {
      await _packageReadinessService.recordWarningAcknowledged(
        courseId: currentState.courseId!,
        packageId: currentState.packageId ?? '',
        reason: _mapStatusToReason(currentState.packageReadiness!.status),
      );
    }

    emit(currentState.copyWith(warningAcknowledged: true));
  }

  PackageReadinessReason _mapStatusToReason(PackageStatus status) {
    switch (status) {
      case PackageStatus.notChecked:
        return PackageReadinessReason.notDownloaded;
      case PackageStatus.valid:
        return PackageReadinessReason.ok;
      case PackageStatus.invalid:
        return PackageReadinessReason.checksumMismatch;
      case PackageStatus.expired:
        return PackageReadinessReason.expired;
      case PackageStatus.notDownloaded:
        return PackageReadinessReason.notDownloaded;
    }
  }

  // ─── Nearby Courses ──────────────────────────────────────────────────────────

  /// One fix, one query, and whatever comes back is a suggestion.
  ///
  /// Every failure here is silent and ordinary: permission refused, location
  /// off, indoors with no sky, or simply no course within the radius. The
  /// picker already works without it.
  Future<void> _suggestNearby() async {
    final location = _locationService;
    if (location == null) return;
    try {
      final fix = await location
          .getCurrentLocation()
          .timeout(const Duration(seconds: 8));
      if (fix.source == LocationSource.unavailable) return;

      final page = await _courseSearchApi.findNearbyCourses(
        latitude: fix.latitude,
        longitude: fix.longitude,
        // Wide enough to cover the drive a golfer makes to play — Hanoi's
        // courses are an hour out — and narrow enough that "near you" still
        // means something.
        radiusMeters: 60000,
        size: 10,
      );
      if (isClosed) return;
      add(NearbyCoursesLoaded(
        page.content
            .map((c) => NearbyCourseSuggestion(
                  courseId: c.courseId,
                  courseName: c.courseName ?? c.facilityName,
                  latitude: c.latitude,
                  longitude: c.longitude,
                  distanceKm: c.distanceMeters == null
                      ? null
                      : c.distanceMeters! / 1000,
                  packageId: null,
                ))
            .toList(),
      ));
    } catch (_) {
      // No fix, no permission, no network, no courses. All the same answer.
    }
  }

  Future<void> _onNearbyCoursesLoaded(
    NearbyCoursesLoaded event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(currentState.copyWith(nearbyCourses: event.courses));
  }

  Future<void> _onLastPlayedCoursesLoaded(
    LastPlayedCoursesLoaded event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(currentState.copyWith(recentCourses: event.courses));
  }

  // ─── Tournament Policy ───────────────────────────────────────────────────────

  Future<void> _onTournamentPolicySelected(
    TournamentPolicySelected event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(currentState.copyWith(tournamentPolicyId: event.policyId));
  }

  // ─── Round Start ─────────────────────────────────────────────────────────────

  Future<void> _onStartRoundTapped(
    StartRoundTapped event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;
    if (!currentState.isStartEnabled) return;

    emit(currentState.copyWith(isSubmitting: true));

    try {
      // Build RoundConfig
      final config = RoundConfig(
        courseId: currentState.courseId!,
        courseName: currentState.courseName!,
        layoutId: currentState.selectedLayoutId,
        teeId: currentState.selectedTeeId,
        format: currentState.format,
        playerIds: currentState.players.map((p) => p.id).toList(),
        players: currentState.players,
        mode: currentState.mode,
        bagId: currentState.selectedBagId,
        startHole: currentState.startHole,
        holes: currentState.holes,
        startTime: DateTime.now(),
        packageId: currentState.packageId,
        tournamentPolicyId: currentState.tournamentPolicyId,
      );

      // Validate config
      final validation = config.validate();
      if (!validation.isValid) {
        emit(
          RoundSetupError(
            message: validation.errors.first.message,
            lastState: currentState.copyWith(
              validationErrors: validation.errors
                  .map((e) => e.message)
                  .toList(),
              isSubmitting: false,
            ),
          ),
        );
        return;
      }

      // Generate idempotency key for API call
      final idempotencyKey = _uuid.v4();

      // Save locally first (offline-first)
      final localId = _uuid.v4();
      final localRecord = LocalRoundConfigRecord.fromRoundConfig(
        localId: localId,
        config: config,
        idempotencyKey: idempotencyKey,
      );
      await _roundSetupStore.saveLocalRoundConfig(localRecord);

      // Create the round server-side. On any API/network failure we keep the
      // locally saved config and play on with the local id — the round is
      // already persisted, so the golfer is never blocked from teeing off.
      String roundId = localId;
      var syncedToServer = false;
      try {
        final created = await _roundApi.createRound(
          courseId: config.courseId,
          segmentCourseIds: currentState.segmentCourseIds,
          idempotencyKey: idempotencyKey,
          startTime: config.startTime,
          packageId: int.tryParse(config.packageId ?? ''),
          tournamentPolicyId: config.tournamentPolicyId,
        );
        roundId = created.id;
        syncedToServer = true;
        await _roundSetupStore.markSynced(localId, roundId);
      } on VspApiException {
        await _roundSetupStore.markSyncFailed(localId);
      } catch (_) {
        await _roundSetupStore.markSyncFailed(localId);
      }

      // Persist the round locally so the scorecard, the active-round guard and
      // the completion flow all resolve the same round id.
      await _roundRepo.createRound(
        Round(
          id: roundId,
          courseId: config.courseId,
          courseName: config.courseName,
          status: RoundStatus.inProgress,
          startedAt: config.startTime,
          packageVersion: config.packageId ?? 'unknown',
          tournamentPolicyId: config.tournamentPolicyId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Record round start in guard (locks the package version for this round)
      await _activeRoundGuard.recordRoundStart(
        config.courseId,
        roundId: roundId,
      );

      // Record course as played (for recent/fallback)
      await _nearbyCourseService.recordCoursePlayed(
        courseId: config.courseId,
        courseName: config.courseName,
        packageId: config.packageId,
      );

      if (syncedToServer) {
        emit(
          RoundSetupRoundStarted(
            roundId: roundId,
            courseId: config.courseId,
            courseName: config.courseName,
          ),
        );
      } else {
        emit(
          RoundSetupLocalRoundSaved(
            courseId: config.courseId,
            courseName: config.courseName,
            localRoundId: roundId,
          ),
        );
      }
    } catch (ex) {
      emit(
        RoundSetupError(
          message: AppMessages.roundStartFailed,
          lastState: currentState.copyWith(isSubmitting: false),
        ),
      );
    }
  }
}
