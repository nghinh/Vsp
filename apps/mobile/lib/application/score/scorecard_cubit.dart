// Scorecard Cubit — VSP Mobile App
//
// Manages the full scorecard screen state.
// Handles hole navigation, score updates, and offline state tracking.
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/score.dart';
import '../../domain/models/score_value_objects.dart';
import '../../domain/models/sync_status.dart';
import '../../domain/repositories/score_repository.dart';
import '../../data/repositories/score_repository_impl.dart';
import 'scorecard_state.dart';

/// Cubit for managing the full scorecard screen state.
class ScorecardCubit extends Cubit<ScorecardScreenState> {
  final ScoreRepository _scoreRepository;

  ScorecardCubit({
    required String flightId,
    required List<String> holeIds,
    required List<String> playerIds,
    Map<String, String>? playerNames,
    Map<String, int>? holePars,
    bool isTournamentMode = false,
    ScoreRepository? scoreRepository,
  }) : _scoreRepository = scoreRepository ?? ScoreRepositoryImpl(),
       super(
         ScorecardScreenState(
           flightId: flightId,
           holeIds: holeIds,
           playerIds: playerIds,
           playerNames: playerNames ?? {},
           holePars: holePars ?? {},
           isTournamentMode: isTournamentMode,
         ),
       );

  /// Load all scores for the scorecard from SQLite.
  Future<void> loadScores() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final allScores = await _scoreRepository.getScoresForFlight(
        state.flightId,
      );

      // Build the score matrix: playerId → holeId → Score
      final scoreMatrix = <String, Map<String, Score>>{};
      for (final playerId in state.playerIds) {
        scoreMatrix[playerId] = {};
      }
      for (final score in allScores) {
        if (scoreMatrix.containsKey(score.playerId)) {
          scoreMatrix[score.playerId]![score.holeId] = score;
        }
      }

      // Check if any scores have unsynced status (offline indicator)
      final hasOffline = allScores.any((s) => s.syncStatus.needsSync);

      // Derive aggregate SyncStatus from scores' sync status.
      final syncStatus = _deriveSyncStatus(allScores);

      emit(
        state.copyWith(
          scores: scoreMatrix,
          isLoading: false,
          isOffline: hasOffline,
          syncStatus: syncStatus,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load scores: $e',
        ),
      );
    }
  }

  /// Update or create a score for a player on the current hole.
  Future<void> updateScore({
    required String playerId,
    int? grossScore,
    int? putts,
    int? penalties,
    bool? fairwayHit,
    bool? gir,
    bool? bunker,
    String? notes,
  }) async {
    final holeId = state.currentHoleId;
    if (holeId == null) return;

    final existing = state.getScore(playerId, holeId);
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
            syncStatus: ScoreSyncStatus.local,
            updatedAt: now,
          )
        : Score(
            id: '${state.flightId}_${holeId}_$playerId',
            flightId: state.flightId,
            holeId: holeId,
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

    try {
      await _scoreRepository.upsertScore(updated);
      final newScores = Map<String, Map<String, Score>>.from(state.scores);
      newScores[playerId] = Map<String, Score>.from(newScores[playerId] ?? {});
      newScores[playerId]![holeId] = updated;
      emit(
        state.copyWith(
          scores: newScores,
          isOffline: true,
          syncStatus: SyncStatus.pending,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to save score: $e'));
    }
  }

  /// Increment gross score for a player on the current hole.
  Future<void> incrementGrossScore(String playerId, {int by = 1}) async {
    final holeId = state.currentHoleId;
    if (holeId == null) return;
    final current = state.getScore(playerId, holeId)?.grossScore ?? 0;
    await updateScore(playerId: playerId, grossScore: current + by);
  }

  /// Decrement gross score for a player on the current hole.
  Future<void> decrementGrossScore(String playerId, {int by = 1}) async {
    final holeId = state.currentHoleId;
    if (holeId == null) return;
    final current = state.getScore(playerId, holeId)?.grossScore ?? 0;
    final newScore = (current - by).clamp(1, 30);
    await updateScore(playerId: playerId, grossScore: newScore);
  }

  /// Set gross score directly for a player on the current hole.
  Future<void> setGrossScore(String playerId, int score) async {
    await updateScore(playerId: playerId, grossScore: score);
  }

  /// Navigate to the previous hole.
  void navigateToPreviousHole() {
    if (!state.canGoBack) return;
    emit(state.copyWith(currentHoleIndex: state.currentHoleIndex - 1));
  }

  /// Navigate to the next hole.
  void navigateToNextHole() {
    if (!state.canGoForward) return;
    emit(state.copyWith(currentHoleIndex: state.currentHoleIndex + 1));
  }

  /// Navigate to a specific hole index.
  void navigateToHoleIndex(int index) {
    if (index < 0 || index >= state.totalHoles) return;
    emit(state.copyWith(currentHoleIndex: index));
  }

  /// Clear the error message.
  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }

  /// Derive aggregate [SyncStatus] from a list of scores.
  SyncStatus _deriveSyncStatus(List<Score> scores) {
    if (scores.isEmpty) return SyncStatus.synced;

    final hasUnsynced = scores.any((s) => s.syncStatus.needsSync);
    if (hasUnsynced) return SyncStatus.pending;
    return SyncStatus.synced;
  }

  // ─── Progressive Field Updates ─────────────────────────────────────────────

  /// Update putts for a player on the current hole.
  Future<void> incrementPutts(String playerId) async {
    final holeId = state.currentHoleId;
    if (holeId == null) return;
    final current = state.getScore(playerId, holeId)?.putts ?? 0;
    final newValue = (current + 1).clamp(0, 15);
    await updateScore(playerId: playerId, putts: newValue);
  }

  /// Update putts for a player on the current hole.
  Future<void> decrementPutts(String playerId) async {
    final holeId = state.currentHoleId;
    if (holeId == null) return;
    final current = state.getScore(playerId, holeId)?.putts ?? 0;
    final newValue = (current - 1).clamp(0, 15);
    await updateScore(playerId: playerId, putts: newValue);
  }

  /// Update penalties for a player on the current hole.
  Future<void> incrementPenalties(String playerId) async {
    final holeId = state.currentHoleId;
    if (holeId == null) return;
    final current = state.getScore(playerId, holeId)?.penalties ?? 0;
    final newValue = (current + 1).clamp(0, 10);
    await updateScore(playerId: playerId, penalties: newValue);
  }

  /// Update penalties for a player on the current hole.
  Future<void> decrementPenalties(String playerId) async {
    final holeId = state.currentHoleId;
    if (holeId == null) return;
    final current = state.getScore(playerId, holeId)?.penalties ?? 0;
    final newValue = (current - 1).clamp(0, 10);
    await updateScore(playerId: playerId, penalties: newValue);
  }

  /// Set fairway hit for a player on the current hole.
  Future<void> setFairwayHit(String playerId, bool? value) async {
    await updateScore(playerId: playerId, fairwayHit: value);
  }

  /// Set GIR for a player on the current hole.
  Future<void> setGir(String playerId, bool? value) async {
    await updateScore(playerId: playerId, gir: value);
  }

  /// Set bunker for a player on the current hole.
  Future<void> setBunker(String playerId, bool? value) async {
    await updateScore(playerId: playerId, bunker: value);
  }

  /// Set notes for a player on the current hole.
  Future<void> setNotes(String playerId, String? notes) async {
    await updateScore(playerId: playerId, notes: notes);
  }
}
