// SmartTargetState — VSP Mobile App
//
// State for Smart Target recommendations.
//
// Per slice-plan-11-4.md Slice 3:
// - ChangeNotifier state management
// - Loading/available/unavailable/error states
//
// Story 11.4 — Slice 3: State Management

import 'package:equatable/equatable.dart';

import '../../../domain/analytics/smart_target/models/smart_target_recommendation.dart';
import '../../../domain/analytics/smart_target/models/strategy_option.dart';
import '../../../domain/models/tournament_policy.dart';

/// Status lifecycle for Smart Target recommendations.
enum SmartTargetStatus {
  /// Initial idle state, no generation attempted.
  idle,

  /// Actively generating recommendation.
  loading,

  /// Recommendation available.
  available,

  /// Generation failed (error).
  error,

  /// Feature unavailable due to policy or insufficient data.
  unavailable,
}

/// State for Smart Target provider.
///
/// Tracks the lifecycle of Smart Target generation including:
/// - [status]: generation lifecycle
/// - [recommendation]: the generated recommendation (when available)
/// - [selectedStrategyIndex]: which strategy is currently selected (0=safe, 1=balanced, 2=aggressive)
/// - [tournamentPolicy]: current tournament policy (for UI to show restrictions)
/// - [loading]: loading flag for UI
/// - [errorMessage]: error message when status is error
class SmartTargetState extends Equatable {
  /// Current generation lifecycle status.
  final SmartTargetStatus status;

  /// The generated recommendation (null when not available).
  final SmartTargetRecommendation? recommendation;

  /// Currently selected strategy index (0=safe, 1=balanced, 2=aggressive).
  final int selectedStrategyIndex;

  /// Tournament policy for display purposes (to show restriction reasons).
  final TournamentPolicy? tournamentPolicy;

  /// True if generating.
  final bool loading;

  /// Error message when status is error.
  final String? errorMessage;

  /// Timestamp when recommendation was generated.
  final DateTime? generatedAt;

  const SmartTargetState({
    this.status = SmartTargetStatus.idle,
    this.recommendation,
    this.selectedStrategyIndex = 0,
    this.tournamentPolicy,
    this.loading = false,
    this.errorMessage,
    this.generatedAt,
  });

  /// Initial idle state.
  factory SmartTargetState.initial() {
    return const SmartTargetState();
  }

  // ─── Convenience getters ───────────────────────────────────────────────────

  /// True if a recommendation is available.
  bool get hasRecommendation => status == SmartTargetStatus.available;

  /// True if feature is unavailable (policy or data reason).
  bool get isUnavailable => status == SmartTargetStatus.unavailable;

  /// True if currently loading.
  bool get isLoading => status == SmartTargetStatus.loading || loading;

  /// True if in error state.
  bool get isError => status == SmartTargetStatus.error;

  /// True if idle (no generation attempted).
  bool get isIdle => status == SmartTargetStatus.idle;

  /// Current strategy option based on selected index.
  StrategyOption? get selectedStrategy {
    if (recommendation == null || recommendation!.strategyOptions == null) {
      return null;
    }
    final opts = recommendation!.strategyOptions!;
    if (selectedStrategyIndex >= opts.length) return opts.first;
    return opts[selectedStrategyIndex];
  }

  /// True if tournament policy restricts this feature.
  bool get isRestrictedByPolicy =>
      recommendation?.isRestrictedByPolicy ?? false;

  /// Unavailability reason label for display.
  String? get unavailabilityReason => recommendation?.reasonLabel;

  // ─── Mutators ─────────────────────────────────────────────────────────────

  /// Copy with updated fields.
  SmartTargetState copyWith({
    SmartTargetStatus? status,
    SmartTargetRecommendation? recommendation,
    int? selectedStrategyIndex,
    TournamentPolicy? tournamentPolicy,
    bool? loading,
    String? errorMessage,
    DateTime? generatedAt,
    // Clear recommendation when appropriate
    bool clearRecommendation = false,
  }) {
    return SmartTargetState(
      status: status ?? this.status,
      recommendation: clearRecommendation
          ? null
          : (recommendation ?? this.recommendation),
      selectedStrategyIndex:
          selectedStrategyIndex ?? this.selectedStrategyIndex,
      tournamentPolicy: tournamentPolicy ?? this.tournamentPolicy,
      loading: loading ?? this.loading,
      errorMessage: errorMessage ?? this.errorMessage,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    recommendation,
    selectedStrategyIndex,
    tournamentPolicy,
    loading,
    errorMessage,
    generatedAt,
  ];
}
