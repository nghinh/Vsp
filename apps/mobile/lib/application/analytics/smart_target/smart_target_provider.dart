// SmartTargetProvider — VSP Mobile App
//
// ChangeNotifier for Smart Target state management.
//
// Per slice-plan-11-4.md Slice 3:
// - ChangeNotifier state management
// - Loading/available/unavailable/error states
// - Tournament policy awareness
//
// Story 11.4 — Slice 3: State Management

import 'package:flutter/foundation.dart';

import '../../../domain/analytics/smart_target/models/smart_target_recommendation.dart';
import '../../../domain/analytics/smart_target/models/strategy_option.dart';
import '../../../domain/models/tournament_policy.dart';
import '../../../domain/value_objects/lat_lng.dart';
import 'smart_target_state.dart';

/// Provider for Smart Target recommendations.
///
/// Manages the lifecycle of Smart Target generation:
/// - Subscribes to location/golfer state changes
/// - Triggers regeneration when position or hole changes
/// - Handles tournament policy restrictions
/// - Provides selected strategy for display
///
/// Usage:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => SmartTargetProvider(
///     clubPerformanceRepo: clubPerformanceRepo,
///     strokesGainedRepo: strokesGainedRepo,
///     holeGeometryProvider: holeGeometryProvider,
///   ),
///   child: SmartTargetPanel(),
/// )
/// ```
class SmartTargetProvider extends ChangeNotifier {
  /// Repository for club performance data (Story 11.1).
  final dynamic clubPerformanceRepo;

  /// Repository for strokes gained data (Story 11.3).
  final dynamic strokesGainedRepo;

  /// Provider for hole geometry data (Epic 6).
  final dynamic holeGeometryProvider;

  /// Use case for generating Smart Target.
  /// Set during initialization if available.
  dynamic _useCase;

  SmartTargetState _state = SmartTargetState.initial();

  SmartTargetProvider({
    required this.clubPerformanceRepo,
    required this.strokesGainedRepo,
    required this.holeGeometryProvider,
    dynamic useCase,
  }) : _useCase = useCase;

  /// Current state.
  SmartTargetState get state => _state;

  /// Current recommendation if available.
  SmartTargetRecommendation? get recommendation => _state.recommendation;

  /// Current selected strategy option.
  StrategyOption? get selectedStrategy => _state.selectedStrategy;

  /// All strategy options if available.
  List<StrategyOption>? get strategyOptions =>
      _state.recommendation?.strategyOptions;

  /// True if feature is restricted by tournament policy.
  bool get isRestrictedByPolicy => _state.isRestrictedByPolicy;

  /// True if currently loading.
  bool get isLoading => _state.isLoading;

  /// Error message if in error state.
  String? get errorMessage => _state.errorMessage;

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Set the tournament policy and regenerate if needed.
  void setTournamentPolicy(TournamentPolicy? policy) {
    _state = _state.copyWith(tournamentPolicy: policy);
    notifyListeners();
  }

  /// Generate Smart Target for a given hole and golfer position.
  ///
  /// Call this when:
  /// - Hole changes
  /// - Golfer position updates significantly (>5m change)
  /// - User requests refresh
  Future<void> generate({
    required String playerId,
    required LatLng golferPosition,
    required String holeId,
    int? holeNumber,
    String? courseId,
    double? handicap,
    TournamentPolicy? tournamentPolicy,
  }) async {
    _state = _state.copyWith(
      status: SmartTargetStatus.loading,
      loading: true,
      errorMessage: null,
    );
    notifyListeners();

    try {
      SmartTargetRecommendation result;

      if (_useCase != null) {
        // Use the wired use case
        result =
            await _useCase.execute(
                  playerId: playerId,
                  golferPosition: golferPosition,
                  holeId: holeId,
                  holeNumber: holeNumber ?? 1,
                  courseId: courseId,
                  handicap: handicap,
                  tournamentPolicy: tournamentPolicy,
                )
                as SmartTargetRecommendation;
      } else {
        // No use case wired - return unavailable
        result = SmartTargetRecommendation.unavailable(
          reason: UnavailabilityReason.noClubPerformanceData,
          reasonLabel: 'Smart Target not yet configured',
          generatedAt: DateTime.now(),
        );
      }

      _state = _state.copyWith(
        status: result.available
            ? SmartTargetStatus.available
            : SmartTargetStatus.unavailable,
        recommendation: result,
        loading: false,
        generatedAt: result.generatedAt,
        tournamentPolicy: tournamentPolicy,
      );
    } catch (e) {
      _state = _state.copyWith(
        status: SmartTargetStatus.error,
        loading: false,
        errorMessage: 'Failed to generate Smart Target: $e',
      );
    }

    notifyListeners();
  }

  /// Select a strategy by index (0=safe, 1=balanced, 2=aggressive).
  void selectStrategy(int index) {
    if (index < 0) return;

    final opts = strategyOptions;
    if (opts != null && index >= opts.length) return;

    _state = _state.copyWith(selectedStrategyIndex: index);
    notifyListeners();
  }

  /// Select safe strategy.
  void selectSafe() => selectStrategy(0);

  /// Select balanced strategy.
  void selectBalanced() => selectStrategy(1);

  /// Select aggressive strategy.
  void selectAggressive() => selectStrategy(2);

  /// Clear the current recommendation and reset to idle.
  void clear() {
    _state = SmartTargetState.initial();
    notifyListeners();
  }

  /// Handle data unavailability gracefully.
  ///
  /// Called when 11.1/11.3 data is not yet synced.
  void handleDataUnavailable({required String reason, String? reasonLabel}) {
    _state = _state.copyWith(
      status: SmartTargetStatus.unavailable,
      loading: false,
      recommendation: SmartTargetRecommendation.unavailable(
        reason:
            UnavailabilityReason.fromValue(reason) ??
            UnavailabilityReason.insufficientHistory,
        reasonLabel: reasonLabel ?? 'Not enough round history',
        generatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Handle insufficient data state.
  void handleInsufficientData(int availableClubs, int requiredClubs) {
    _state = _state.copyWith(
      status: SmartTargetStatus.unavailable,
      loading: false,
      recommendation: SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.insufficientHistory,
        reasonLabel:
            'Not enough club data. Need $requiredClubs clubs, got $availableClubs.',
        generatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Handle no hole geometry state.
  void handleNoHoleGeometry() {
    _state = _state.copyWith(
      status: SmartTargetStatus.unavailable,
      loading: false,
      recommendation: SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.noHoleData,
        reasonLabel: 'Hole geometry not available',
        generatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Handle tournament policy restriction.
  void handlePolicyRestriction(TournamentPolicy policy, String? reason) {
    _state = _state.copyWith(
      status: SmartTargetStatus.unavailable,
      loading: false,
      tournamentPolicy: policy,
      recommendation: SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.restrictedByPolicy,
        reasonLabel: reason ?? 'Smart Target is disabled in tournament mode',
        generatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
