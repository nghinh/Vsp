// Round Review State — VSP Mobile App
//
// State classes for the Round Review screen.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.

import 'package:equatable/equatable.dart';

import '../../../domain/models/round_review_metrics.dart';
import '../../../features/round/domain/score_entry.dart';

/// Screen state for the Round Review view.
sealed class RoundReviewState extends Equatable {
  const RoundReviewState();
}

// ─── Concrete States ───────────────────────────────────────────────────────────

/// Initial state before any data is loaded.
class RoundReviewInitial extends RoundReviewState {
  const RoundReviewInitial();

  @override
  List<Object?> get props => [];
}

/// Loading state while fetching round review metrics.
class RoundReviewLoading extends RoundReviewState {
  const RoundReviewLoading();

  @override
  List<Object?> get props => [];
}

/// No data found for the given round.
class RoundReviewEmpty extends RoundReviewState {
  final String roundId;

  const RoundReviewEmpty({required this.roundId});

  @override
  List<Object?> get props => [roundId];
}

/// Successfully loaded round review metrics.
class RoundReviewLoaded extends RoundReviewState {
  final RoundReviewMetrics metrics;

  /// The golfer's card, hole by hole, ordered by hole number.
  ///
  /// The screen reported only round totals, so a golfer who wanted to see what
  /// they shot on the 7th had nowhere to look. Empty when the round was played
  /// without a card.
  final List<ScoreEntry> holeScores;

  const RoundReviewLoaded({
    required this.metrics,
    this.holeScores = const [],
  });

  @override
  List<Object?> get props => [metrics, holeScores];
}

/// Error state when loading fails.
class RoundReviewError extends RoundReviewState {
  final String message;
  final String? roundId;

  const RoundReviewError({required this.message, this.roundId});

  @override
  List<Object?> get props => [message, roundId];
}
