// Hole Score Cubit — VSP Mobile App
//
// Manages the state for a single hole's score entry.
// Handles loading scores for a hole and updating individual player scores.
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/score.dart';
import '../../domain/models/score_value_objects.dart';
import '../../domain/repositories/score_repository.dart';
import 'hole_score_state.dart';

/// Cubit for managing hole-level score entry state.
class HoleScoreCubit extends Cubit<HoleScoreState> {
  final ScoreRepository _scoreRepository;

  HoleScoreCubit({
    required String flightId,
    required String holeId,
    required ScoreRepository scoreRepository,
  }) : _scoreRepository = scoreRepository,
       super(HoleScoreState(flightId: flightId, holeId: holeId));

  /// Load scores for all players on the current hole.
  Future<void> loadScores(List<String> playerIds) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final scores = <String, Score>{};
      for (final playerId in playerIds) {
        final score = await _scoreRepository.getScore(
          flightId: state.flightId,
          holeId: state.holeId,
          playerId: playerId,
        );
        if (score != null) {
          scores[playerId] = score;
        }
      }
      emit(state.copyWith(scores: scores, isLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load scores: $e',
        ),
      );
    }
  }

  /// Update or create a score for a player.
  Future<void> updatePlayerScore({
    required String playerId,
    int? grossScore,
    int? putts,
    int? penalties,
    bool? fairwayHit,
    bool? gir,
    bool? bunker,
    String? notes,
  }) async {
    final existing = state.scores[playerId];
    final now = DateTime.now();

    final updated = existing != null
        ? existing.copyWith(
            grossScore: grossScore,
            putts: putts,
            penalties: penalties,
            fairwayHit: fairwayHit,
            gir: gir,
            bunker: bunker,
            notes: notes,
            enteredAt: existing.enteredAt ?? now,
            syncStatus: ScoreSyncStatus.local,
            updatedAt: now,
          )
        : Score(
            id: '${state.flightId}_${state.holeId}_$playerId',
            flightId: state.flightId,
            holeId: state.holeId,
            playerId: playerId,
            grossScore: grossScore,
            putts: putts,
            penalties: penalties,
            fairwayHit: fairwayHit,
            gir: gir,
            bunker: bunker,
            notes: notes,
            enteredAt: now,
            syncStatus: ScoreSyncStatus.local,
            updatedAt: now,
          );

    // Persist to SQLite
    try {
      await _scoreRepository.upsertScore(updated);
      final newScores = Map<String, Score>.from(state.scores);
      newScores[playerId] = updated;
      emit(state.copyWith(scores: newScores, hasUnsavedChanges: false));
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'Failed to save score: $e',
          hasUnsavedChanges: true,
        ),
      );
    }
  }

  /// Increment gross score for a player by 1.
  Future<void> incrementGrossScore(String playerId, {int by = 1}) async {
    final current = state.scores[playerId]?.grossScore ?? 0;
    await updatePlayerScore(playerId: playerId, grossScore: current + by);
  }

  /// Decrement gross score for a player by 1.
  Future<void> decrementGrossScore(String playerId, {int by = 1}) async {
    final current = state.scores[playerId]?.grossScore ?? 0;
    final newScore = (current - by).clamp(1, 30);
    await updatePlayerScore(playerId: playerId, grossScore: newScore);
  }

  /// Set gross score directly for a player.
  Future<void> setGrossScore(String playerId, int score) async {
    await updatePlayerScore(playerId: playerId, grossScore: score);
  }

  /// Clear the error message.
  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }
}
