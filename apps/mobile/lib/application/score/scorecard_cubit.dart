// Scorecard Cubit — VSP Mobile App
//
// Manages the full scorecard screen state.
// Handles hole navigation, score updates, and offline state tracking.
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/score.dart';
import '../../domain/models/score_value_objects.dart';
import '../../domain/models/sync_event.dart';
import '../../domain/models/sync_status.dart';
import '../../domain/repositories/score_repository.dart';
import '../../data/repositories/score_repository_impl.dart';
import '../../infrastructure/persistence/sync_queue_repository.dart';
import 'scorecard_state.dart';

/// Cubit for managing the full scorecard screen state.
class ScorecardCubit extends Cubit<ScorecardScreenState> {
  final ScoreRepository _scoreRepository;
  final SyncQueueRepository _syncQueue;
  static const Uuid _uuid = Uuid();

  ScorecardCubit({
    required String flightId,
    required List<String> holeIds,
    required List<String> playerIds,
    Map<String, String>? playerNames,
    Map<String, int>? holePars,
    bool isTournamentMode = false,
    ScoreRepository? scoreRepository,
    SyncQueueRepository? syncQueue,
    int initialHoleIndex = 0,
  }) : _scoreRepository = scoreRepository ?? ScoreRepositoryImpl(),
       _syncQueue = syncQueue ?? SyncQueueRepository(),
       super(
         ScorecardScreenState(
           flightId: flightId,
           holeIds: holeIds,
           playerIds: playerIds,
           playerNames: playerNames ?? {},
           holePars: holePars ?? {},
           isTournamentMode: isTournamentMode,
           // Resuming a round works out which hole the golfer stopped on, and
           // the scorecard used to ignore it and open on the 1st tee anyway —
           // so a golfer who came back on the 7th had to tap forward six times
           // before they could enter the score they came back to enter.
           currentHoleIndex:
               initialHoleIndex >= 0 && initialHoleIndex < holeIds.length
               ? initialHoleIndex
               : 0,
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
      await _enqueueSync(updated);
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


  /// Write a whole card's worth of strokes at once.
  ///
  /// Entering eighteen holes one at a time is eighteen taps of Next between
  /// eighteen keypads; a card photographed after the round is all eighteen at
  /// once, and paging through the scorecard to type numbers the golfer has
  /// already checked would undo the point of photographing it.
  ///
  /// Each hole still goes through the same upsert and the same sync queue as a
  /// hand-entered stroke, so a scanned round syncs, resumes and corrects
  /// identically. Only the typing is skipped — never a check.
  ///
  /// Returns how many holes were written.
  Future<int> applyScannedStrokes({
    required String playerId,
    required Map<int, int> grossByHole,
  }) async {
    final now = DateTime.now();
    final newScores = Map<String, Map<String, Score>>.from(state.scores);
    newScores[playerId] = Map<String, Score>.from(newScores[playerId] ?? {});

    var written = 0;
    for (final entry in grossByHole.entries) {
      final holeId = '${entry.key}';
      // A hole this round does not play is not a hole to write to. A card
      // photographed on the wrong nine would otherwise leave scores hanging
      // off hole ids the round has never heard of.
      if (!state.holeIds.contains(holeId)) continue;

      final existing = state.getScore(playerId, holeId);
      final updated = existing != null
          ? existing.copyWith(
              grossScore: entry.value,
              syncStatus: ScoreSyncStatus.local,
              updatedAt: now,
            )
          : Score(
              id: '${state.flightId}_${holeId}_$playerId',
              flightId: state.flightId,
              holeId: holeId,
              playerId: playerId,
              grossScore: entry.value,
              enteredAt: now,
              syncStatus: ScoreSyncStatus.local,
              updatedAt: now,
            );

      try {
        await _scoreRepository.upsertScore(updated);
        await _enqueueSync(updated);
        newScores[playerId]![holeId] = updated;
        written++;
      } catch (_) {
        // One hole that would not write is not a reason to drop the other
        // seventeen. The golfer sees which holes landed on the scorecard.
      }
    }

    if (written > 0) {
      emit(
        state.copyWith(
          scores: newScores,
          isOffline: true,
          syncStatus: SyncStatus.pending,
        ),
      );
    }
    return written;
  }

  /// Queues a score for the server.
  ///
  /// Every stroke used to stop at SQLite: `upsertScore` and nothing else. The
  /// queue, the route and the endpoint all existed — `SyncEvent.forScore` had
  /// no caller anywhere in the app — so a finished round left the phone with
  /// zero `/scores/sync` requests, and the server held a scorecard with no
  /// holes on it.
  Future<void> _enqueueSync(Score score) async {
    // The server keys a score update by golfer account id. The primary player
    // carries theirs as their id; a guest added on the tee has no account, so
    // their card stays on this phone rather than being posted under somebody
    // else's name.
    final golferAccountId = int.tryParse(score.playerId);
    final holeIndex = int.tryParse(score.holeId);
    if (golferAccountId == null || holeIndex == null) {
      return;
    }

    try {
      await _syncQueue.append(
        SyncEvent.forScore(
          scoreId: score.id,
          // Shaped as the batch the endpoint takes, so the queue sends
          // ScoreSyncRequest exactly: roundId and flightId in the envelope,
          // and nothing in the ScoreUpdate that the record does not declare.
          // Flattening it here would leave those two inside the update, and
          // whether Jackson ignores unknown fields is a server setting the
          // queue should not depend on.
          scorePayload: {
            'roundId': score.flightId,
            'flightId': score.flightId,
            'scores': [
              {
                // ScoreUpdate.scoreId is a UUID server-side; the local id is a
                // `flight_hole_player` composite. Derived rather than random,
                // so re-entering a hole updates that row instead of adding a
                // second one for it.
                'scoreId': _uuid.v5(
                  Uuid.NAMESPACE_URL,
                  'vsp/score/${score.id}',
                ),
                'holeIndex': holeIndex,
                'playerId': golferAccountId,
                'grossScore': score.grossScore,
                'putts': score.putts,
                'penalties': score.penalties,
                'fairwayHit': score.fairwayHit,
                'gir': score.gir,
                'bunker': score.bunker,
                'notes': score.notes,
                'version': score.version,
              },
            ],
          },
        ),
      );
    } catch (_) {
      // The score is already in SQLite. A queue that cannot be written is a
      // sync that happens later, not a stroke the golfer has to enter again.
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
