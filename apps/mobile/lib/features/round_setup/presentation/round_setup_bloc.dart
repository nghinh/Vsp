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

import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../data/services/package_readiness_service.dart';
import '../../../data/services/nearby_course_service.dart';
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
  final Uuid _uuid;

  RoundSetupBloc({
    required PackageManifestRepository manifestRepo,
    required RoundRepository roundRepo,
    required ActiveRoundGuard activeRoundGuard,
    required PackageReadinessService packageReadinessService,
    required NearbyCourseService nearbyCourseService,
    required RoundSetupStore roundSetupStore,
    Uuid uuid = const Uuid(),
  }) : _manifestRepo = manifestRepo,
       _roundRepo = roundRepo,
       _activeRoundGuard = activeRoundGuard,
       _packageReadinessService = packageReadinessService,
       _nearbyCourseService = nearbyCourseService,
       _roundSetupStore = roundSetupStore,
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

      // Load nearby courses (GPS-based)
      // In real app, would request GPS location first
      // For now, emit with empty nearby list
      // add(const NearbyCoursesLoaded([]));

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
          recentCourses: recentCourses,
        ),
      );
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

      // Try to create round via API
      // In real app, would call round creation API here
      // For now, simulate success and navigate immediately
      // try {
      //   final round = await _roundRepo.createRound(config, idempotencyKey);
      //   await _activeRoundGuard.recordRoundStart(config.courseId, roundId: round.id);
      //   await _roundSetupStore.markSynced(localId, round.id);
      //
      //   emit(RoundSetupRoundStarted(
      //     roundId: round.id,
      //     courseId: config.courseId,
      //     courseName: config.courseName,
      //   ));
      // } on ApiException catch (e) {
      //   // API failed — save locally, navigate immediately, sync later
      //   await _roundSetupStore.markSyncFailed(localId);
      //
      //   emit(RoundSetupLocalRoundSaved(
      //     courseId: config.courseId,
      //     courseName: config.courseName,
      //     localRoundId: localId,
      //   ));
      // }

      // Simulate successful round creation for MVP
      final simulatedRoundId = 12345;

      // Record round start in guard
      await _activeRoundGuard.recordRoundStart(
        config.courseId,
        roundId: simulatedRoundId.toString(),
      );

      // Mark as synced
      await _roundSetupStore.markSynced(localId, simulatedRoundId.toString());

      // Record course as played (for recent/fallback)
      await _nearbyCourseService.recordCoursePlayed(
        courseId: config.courseId,
        courseName: config.courseName,
        packageId: config.packageId,
      );

      emit(
        RoundSetupRoundStarted(
          roundId: simulatedRoundId,
          courseId: config.courseId,
          courseName: config.courseName,
        ),
      );
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
