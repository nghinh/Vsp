// Round Review Cubit — VSP Mobile App
//
// Manages the Round Review screen state.
// Handles data fetching and loading/error/empty states.
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
// AC2: Round review includes required scoring and shot metrics with
//      incomplete-data warnings.

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/shot_repository_impl.dart';
import '../../../domain/models/round_review_metrics.dart';
import '../../../domain/repositories/shot_repository.dart';
import 'round_review_state.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Cubit for managing the Round Review screen.
class RoundReviewCubit extends Cubit<RoundReviewState> {
  final ShotRepository _shotRepository;

  /// Currently loaded round ID.
  String? _currentRoundId;

  /// Currently loaded player ID.
  String? _currentPlayerId;

  RoundReviewCubit({ShotRepository? shotRepository})
    : _shotRepository = shotRepository ?? ShotRepositoryImpl(),
      super(const RoundReviewInitial());

  /// Current round ID.
  String? get currentRoundId => _currentRoundId;

  /// Current player ID.
  String? get currentPlayerId => _currentPlayerId;

  /// Load round review metrics for the given [roundId] and [playerId].
  ///
  /// Per AC2: surfaces incomplete-data warnings when sample size is insufficient.
  Future<void> loadRoundReview({
    required String roundId,
    required String playerId,
  }) async {
    _currentRoundId = roundId;
    _currentPlayerId = playerId;
    emit(const RoundReviewLoading());

    try {
      final metrics = await _shotRepository.getRoundReviewMetrics(
        roundId: roundId,
        playerId: playerId,
      );

      emit(RoundReviewLoaded(metrics: metrics));
    } catch (e) {
      emit(
        RoundReviewError(
          message: AppMessages.roundReviewLoadFailed,
          roundId: roundId,
        ),
      );
    }
  }

  /// Retry the last failed request.
  Future<void> retry() async {
    final roundId = _currentRoundId;
    final playerId = _currentPlayerId;
    if (roundId == null || playerId == null) return;
    await loadRoundReview(roundId: roundId, playerId: playerId);
  }
}
