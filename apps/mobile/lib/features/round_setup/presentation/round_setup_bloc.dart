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
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../data/services/package_readiness_service.dart';
import '../../../data/services/nearby_course_service.dart';
import '../../../domain/models/round.dart';
import '../../../domain/models/round_config.dart';
import '../../../domain/models/round_format.dart';
import '../../../domain/models/round_mode.dart';
import '../../../domain/models/player.dart';
import '../../../domain/models/course_package_manifest.dart';
import '../../../core/storage/round_setup_store.dart';
import 'round_setup_event.dart';
import 'round_setup_state.dart';

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
  final RoundSetupStore _roundSetupStore;
  final CourseSearchApi _courseSearchApi;
  final RoundApi _roundApi;
  final Uuid _uuid;

  RoundSetupBloc({
    required PackageManifestRepository manifestRepo,
    required RoundRepository roundRepo,
    required ActiveRoundGuard activeRoundGuard,
    required PackageReadinessService packageReadinessService,
    required NearbyCourseService nearbyCourseService,
    required RoundSetupStore roundSetupStore,
    CourseSearchApi? courseSearchApi,
    RoundApi? roundApi,
    Uuid uuid = const Uuid(),
  }) : _manifestRepo = manifestRepo,
       _roundRepo = roundRepo,
       _activeRoundGuard = activeRoundGuard,
       _packageReadinessService = packageReadinessService,
       _nearbyCourseService = nearbyCourseService,
       _roundSetupStore = roundSetupStore,
       _courseSearchApi =
           courseSearchApi ?? CourseSearchApi(apiClient: ApiClient()),
       _roundApi = roundApi ?? RoundApi(),
       _uuid = uuid,
       super(const RoundSetupInitial()) {
    on<LoadInitialData>(_onLoadInitialData);
    on<CourseSelected>(_onCourseSelected);
    on<LayoutSelected>(_onLayoutSelected);
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
      // Load primary player from profile (mock — would come from auth/profile service)
      final primaryPlayer = Player(id: 'self', name: 'Me', isPrimary: true);

      // Load active bag (mock — would come from bag repository)
      final activeBag = BagOption(id: 1, name: 'My Bag', isActive: true);

      // Get suggested start hole based on time of day
      final suggestedHole = RoundSetupReady.suggestedStartHole();

      // Load the course catalogue so the picker always has options, even
      // without GPS. Distance is filled in when the result carries it.
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
          selectedBagId: activeBag.id,
          startHole: suggestedHole,
          nearbyCourses: availableCourses,
          recentCourses: recentCourses,
        ),
      );

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
      emit(RoundSetupError(message: 'Failed to load initial data: $ex'));
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
    await _loadCourseOptions(event.courseId, emit, currentState);

    // Validate package readiness
    add(const PackageValidationRequested());
  }

  Future<void> _loadCourseOptions(
    int courseId,
    Emitter<RoundSetupState> emit,
    RoundSetupReady currentState,
  ) async {
    try {
      final manifest = await _manifestRepo.getActiveManifest(courseId);

      if (manifest != null) {
        // Extract layouts and tees from manifest
        // In a real app, these would come from the manifest's course metadata
        final layouts = _extractLayouts(manifest);
        final tees = _extractTees(manifest);

        emit(
          currentState.copyWith(
            layouts: layouts,
            tees: tees,
            selectedLayoutId: layouts.isNotEmpty ? layouts.first.id : null,
            selectedTeeId: tees.isNotEmpty ? tees.first.id : null,
          ),
        );
      }
    } catch (_) {
      // Ignore — manifest might not be available
    }
  }

  List<LayoutOption> _extractLayouts(CoursePackageManifest manifest) {
    // In a real app, layouts would come from manifest.courseLayouts
    // For now, return a default 18-hole layout
    return const [LayoutOption(id: 1, name: 'Standard', holeCount: 18)];
  }

  List<TeeOption> _extractTees(CoursePackageManifest manifest) {
    // In a real app, tees would come from manifest.teeSets
    // For now, return placeholder tees
    return const [
      TeeOption(id: 1, name: 'White Tees'),
      TeeOption(id: 2, name: 'Blue Tees'),
      TeeOption(id: 3, name: 'Red Tees'),
    ];
  }

  Future<void> _onLayoutSelected(
    LayoutSelected event,
    Emitter<RoundSetupState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RoundSetupReady) return;

    emit(currentState.copyWith(selectedLayoutId: event.layoutId));
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
          message: 'Failed to start round: $ex',
          lastState: currentState.copyWith(isSubmitting: false),
        ),
      );
    }
  }
}
