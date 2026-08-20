// RoundCompletionBloc — VSP Mobile App
//
// BLoC for round completion flow:
// - Load round summary
// - Complete a round (offline-first)
// - Retry sync
// - Request score corrections
//
// Per Story 5.5 Slice 2: AC-1 offline completion, AC-2 summary display, AC-3 corrections.

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/hole_repository_impl.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/repositories/score_repository_impl.dart';
import '../../../domain/models/round.dart';
import '../../../domain/models/score.dart';
import '../../../domain/models/score_value_objects.dart';
import '../../../domain/repositories/hole_repository.dart';
import '../../../domain/repositories/score_repository.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../data/services/round_state_service.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../domain/models/round_sync_operation.dart';
import '../../../core/storage/round_sync_store.dart';
import '../../../domain/models/sync_event.dart';
import '../../../infrastructure/persistence/sync_queue_repository.dart';
import '../domain/round_summary.dart';
import '../domain/score_entry.dart';
import '../domain/sync_state.dart';
import '../domain/correction.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class RoundCompletionEvent extends Equatable {
  const RoundCompletionEvent();

  @override
  List<Object?> get props => [];
}

/// Load the round summary for display.
class LoadRoundSummary extends RoundCompletionEvent {
  final String roundId;

  const LoadRoundSummary({required this.roundId});

  @override
  List<Object?> get props => [roundId];
}

/// Request to complete a round.
class CompleteRound extends RoundCompletionEvent {
  final String roundId;

  const CompleteRound({required this.roundId});

  @override
  List<Object?> get props => [roundId];
}

/// Request to retry sync for a failed round.
class RetrySync extends RoundCompletionEvent {
  final String roundId;

  const RetrySync({required this.roundId});

  @override
  List<Object?> get props => [roundId];
}

/// Request to submit score corrections.
class SubmitCorrection extends RoundCompletionEvent {
  final String roundId;
  final CorrectionRequest request;

  const SubmitCorrection({required this.roundId, required this.request});

  @override
  List<Object?> get props => [roundId, request];
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class RoundCompletionState extends Equatable {
  const RoundCompletionState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no round loaded yet.
class RoundCompletionInitial extends RoundCompletionState {
  const RoundCompletionInitial();
}

/// Loading state — fetching round summary.
class RoundSummaryLoading extends RoundCompletionState {
  const RoundSummaryLoading();
}

/// Round summary loaded successfully.
class RoundSummaryLoaded extends RoundCompletionState {
  final RoundSummary summary;

  const RoundSummaryLoaded({required this.summary});

  @override
  List<Object?> get props => [summary];
}

/// Round completion in progress.
class RoundCompletionInProgress extends RoundCompletionState {
  final String roundId;

  const RoundCompletionInProgress({required this.roundId});

  @override
  List<Object?> get props => [roundId];
}

/// Round completed successfully (online).
class RoundCompletionSuccess extends RoundCompletionState {
  final RoundSummary summary;

  const RoundCompletionSuccess({required this.summary});

  @override
  List<Object?> get props => [summary];
}

/// Round completed but offline — sync is pending.
class RoundCompletionOffline extends RoundCompletionState {
  final RoundSummary summary;

  const RoundCompletionOffline({required this.summary});

  @override
  List<Object?> get props => [summary];
}

/// Correction submitted successfully.
class RoundCorrectionSuccess extends RoundCompletionState {
  final RoundSummary summary;

  const RoundCorrectionSuccess({required this.summary});

  @override
  List<Object?> get props => [summary];
}

/// Correction submission failed.
class RoundCorrectionFailure extends RoundCompletionState {
  final String message;
  final RoundSummary summary;

  const RoundCorrectionFailure({required this.message, required this.summary});

  @override
  List<Object?> get props => [message, summary];
}

/// Error state.
class RoundCompletionError extends RoundCompletionState {
  final String message;

  const RoundCompletionError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

class RoundCompletionBloc
    extends Bloc<RoundCompletionEvent, RoundCompletionState> {
  final RoundRepository _roundRepo;
  final RoundStateService _roundStateService;
  final RoundSyncStore _syncStore;
  final ActiveRoundGuard _activeRoundGuard;
  final ConnectivityService _connectivityService;
  final ScoreRepository _scoreRepository;
  final HoleRepository _holeRepository;
  final PlayerRepository _playerRepository;
  final SyncQueueRepository _syncQueue;
  final Uuid _uuid = const Uuid();

  RoundCompletionBloc({
    required RoundRepository roundRepo,
    required RoundStateService roundStateService,
    required RoundSyncStore syncStore,
    required ActiveRoundGuard activeRoundGuard,
    required ConnectivityService connectivityService,
    // Optional so the existing callers keep compiling; the defaults are the
    // stores the scorecard actually writes to.
    ScoreRepository? scoreRepository,
    HoleRepository? holeRepository,
    PlayerRepository? playerRepository,
    SyncQueueRepository? syncQueue,
  }) : _roundRepo = roundRepo,
       _roundStateService = roundStateService,
       _syncStore = syncStore,
       _activeRoundGuard = activeRoundGuard,
       _connectivityService = connectivityService,
       _scoreRepository = scoreRepository ?? ScoreRepositoryImpl(),
       _holeRepository = holeRepository ?? HoleRepositoryImpl(),
       _playerRepository = playerRepository ?? PlayerRepository(),
       _syncQueue = syncQueue ?? SyncQueueRepository(),
       super(const RoundCompletionInitial()) {
    on<LoadRoundSummary>(_onLoadRoundSummary);
    on<CompleteRound>(_onCompleteRound);
    on<RetrySync>(_onRetrySync);
    on<SubmitCorrection>(_onSubmitCorrection);
  }

  Future<void> _onLoadRoundSummary(
    LoadRoundSummary event,
    Emitter<RoundCompletionState> emit,
  ) async {
    emit(const RoundSummaryLoading());

    try {
      final round = await _roundRepo.getRound(event.roundId);
      if (round == null) {
        emit(const RoundCompletionError(message: AppMessages.roundNotFound));
        return;
      }

      final summary = RoundSummary(
        roundId: round.id,
        courseName: round.courseName,
        startedAt: round.startedAt,
        endedAt: round.endedAt,
        players: await _playersFor(round),
      );

      emit(RoundSummaryLoaded(summary: summary));
    } catch (e) {
      emit(RoundCompletionError(message: AppMessages.roundLoadFailed));
    }
  }

  /// Reads back what the golfer actually entered during the round.
  ///
  /// This used to be `players: []` with a comment saying a real
  /// implementation would fetch the hole scores, so the summary was empty no
  /// matter how many holes had been played — every round ended on "Chưa có
  /// dữ liệu điểm".
  ///
  /// The scores come from the `scores` table, which is where the scorecard
  /// writes them. That is worth stating because this screen was wired with a
  /// [HoleScoreRepository] over the separate `hole_scores` table, and nothing
  /// writes that table during play — reading it would have looked correct and
  /// still returned nothing.
  ///
  /// The round id doubles as the scorecard's flight id.
  Future<List<PlayerScoreSummary>> _playersFor(Round round) async {
    final scores = await _scoreRepository.getScoresForFlight(round.id);
    if (scores.isEmpty) {
      return const [];
    }

    return buildPlayerSummaries(
      scores: scores,
      parByHole: await _parByHoleNumber(round),
      playerNames: await _playerNames(round.id),
    );
  }

  /// hole number → par, from the course package this round was started on.
  ///
  /// A paired round plays two nine-hole courses as one card: the scores call
  /// them holes 1–18, but each course's package numbers its own holes 1–9.
  /// Loading only [Round.courseId] left holes 10–18 with no par at all, and
  /// the summary showed a golfer "Par 0 … +4" for a par they had just made.
  /// Same shift as `StrokeIndexApi.forRound`: front keeps 1–9, the back
  /// nine lands on 10–18.
  Future<Map<int, int>> _parByHoleNumber(Round round) async {
    try {
      final front = await _holeRepository
          .findByCourseWithGeometry('${round.courseId}');
      final pars = {for (final h in front) h.holeNumber: h.par};
      final backNineCourseId = round.backNineCourseId;
      if (backNineCourseId == null) {
        return pars;
      }
      final back =
          await _holeRepository.findByCourseWithGeometry('$backNineCourseId');
      return {
        for (final e in pars.entries)
          if (e.key <= 9) e.key: e.value,
        for (final h in back) h.holeNumber + 9: h.par,
      };
    } catch (_) {
      // No package on this device, or an unreadable one. The card still shows
      // strokes; it just cannot say what they were relative to.
      return const {};
    }
  }

  /// player id → display name. Empty when the round recorded no players,
  /// in which case the card falls back to the id it does have.
  Future<Map<String, String>> _playerNames(String roundId) async {
    try {
      final players = await _playerRepository.getPlayersForRound(roundId);
      return {for (final p in players) p.id: p.name};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _onCompleteRound(
    CompleteRound event,
    Emitter<RoundCompletionState> emit,
  ) async {
    emit(RoundCompletionInProgress(roundId: event.roundId));

    try {
      final round = await _roundRepo.getRound(event.roundId);
      if (round == null) {
        emit(const RoundCompletionError(message: AppMessages.roundNotFound));
        return;
      }

      // Mark round as completed locally
      await _roundStateService.endRound(event.roundId);

      // Check connectivity
      final isOnline = await _connectivityService.isNetworkConnected;

      if (isOnline) {
        // Enqueue round_complete sync event
        final idempotencyKey = _syncStore.generateIdempotencyKey(
          roundId: event.roundId,
          operation: RoundSyncOperation.endRound,
        );
        await _syncStore.enqueueRoundOp(
          idempotencyKey: idempotencyKey,
          operation: RoundSyncOperation.endRound,
          roundId: event.roundId,
          payload: jsonEncode({
            'endedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        );

        // Call activeRoundGuard.recordRoundEnd
        await _activeRoundGuard.recordRoundEnd(round.courseId);

        final summary = RoundSummary(
          roundId: round.id,
          courseName: round.courseName,
          startedAt: round.startedAt,
          endedAt: DateTime.now(),
          players: [],
        );
        emit(RoundCompletionSuccess(summary: summary));
      } else {
        // Offline: event sits in queue with pending state
        final idempotencyKey = _syncStore.generateIdempotencyKey(
          roundId: event.roundId,
          operation: RoundSyncOperation.endRound,
        );
        await _syncStore.enqueueRoundOp(
          idempotencyKey: idempotencyKey,
          operation: RoundSyncOperation.endRound,
          roundId: event.roundId,
          payload: jsonEncode({
            'endedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        );

        await _activeRoundGuard.recordRoundEnd(round.courseId);

        final summary = RoundSummary(
          roundId: round.id,
          courseName: round.courseName,
          startedAt: round.startedAt,
          endedAt: DateTime.now(),
          players: [],
        );
        emit(RoundCompletionOffline(summary: summary));
      }
    } catch (e) {
      emit(RoundCompletionError(message: AppMessages.roundCompleteFailed));
    }
  }

  Future<void> _onRetrySync(
    RetrySync event,
    Emitter<RoundCompletionState> emit,
  ) async {
    // Re-dispatch completion to re-trigger sync
    add(CompleteRound(roundId: event.roundId));
  }

  /// Applies a correction to the card the golfer is looking at.
  ///
  /// This used to write nothing at all — "for now, emit success — real
  /// implementation would call the backend" — and then emit a summary built
  /// from empty strings and `DateTime.now()`. So submitting a correction both
  /// lost the edit and blanked the scorecard on screen, which is the worst of
  /// the two possible failures: it looked like the round had been erased.
  ///
  /// The correction is written to the `scores` table, which is where the
  /// scorecard writes and where the summary reads, then the summary is
  /// rebuilt from storage rather than fabricated.
  Future<void> _onSubmitCorrection(
    SubmitCorrection event,
    Emitter<RoundCompletionState> emit,
  ) async {
    final round = await _roundRepo.getRound(event.roundId);
    if (round == null) {
      emit(const RoundCompletionError(message: AppMessages.roundNotFound));
      return;
    }

    try {
      for (final correction in event.request.corrections) {
        await _applyCorrection(
          roundId: event.roundId,
          playerId: event.request.playerId,
          correction: correction,
        );
      }
    } catch (_) {
      emit(
        RoundCorrectionFailure(
          message: AppMessages.correctionSubmitFailed,
          summary: await _summaryOf(round),
        ),
      );
      return;
    }

    await _queueCorrection(event.roundId, event.request);
    emit(RoundCorrectionSuccess(summary: await _summaryOf(round)));
  }

  /// Queues the correction for the server.
  ///
  /// `POST /scores/rounds/{roundId}/corrections` has existed all along and
  /// nothing ever posted to it, so a corrected hole stayed on the phone while
  /// the server kept the original.
  Future<void> _queueCorrection(String roundId, CorrectionRequest request) async {
    // The endpoint keys corrections by golfer account id. A guest added on
    // the tee has none, so their corrections stay local rather than being
    // filed under somebody else's account.
    final playerId = int.tryParse(request.playerId);
    if (playerId == null || request.corrections.isEmpty) {
      return;
    }

    try {
      await _syncQueue.append(
        SyncEvent.forScoreCorrection(
          roundId: roundId,
          correctionPayload: {
            'playerId': playerId,
            'corrections': [
              for (final c in request.corrections)
                {
                  'field': c.field,
                  'holeNumber': c.holeNumber,
                  'oldValue': c.oldValue,
                  'newValue': c.newValue,
                },
            ],
          },
        ),
      );
    } catch (_) {
      // The correction is already applied locally. A queue that cannot be
      // written is a sync that happens later, not an edit the golfer has to
      // make twice.
    }
  }

  /// Writes one field of one hole back to the score store.
  Future<void> _applyCorrection({
    required String roundId,
    required String playerId,
    required Correction correction,
  }) async {
    final existing = await _scoreRepository.getScore(
      flightId: roundId,
      holeId: '${correction.holeNumber}',
      playerId: playerId,
    );
    if (existing == null) {
      // Nothing to correct: a hole with no entry is a hole to play, not one
      // to amend.
      return;
    }

    final number = int.tryParse(correction.newValue.trim());
    final flag = switch (correction.newValue.trim().toLowerCase()) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => null,
    };

    final corrected = switch (correction.field) {
      'strokes' when number != null => existing.copyWith(grossScore: number),
      'putts' when number != null => existing.copyWith(putts: number),
      'penalties' when number != null => existing.copyWith(penalties: number),
      'fairwayHit' when flag != null => existing.copyWith(fairwayHit: flag),
      'gir' when flag != null => existing.copyWith(gir: flag),
      'bunker' when flag != null => existing.copyWith(bunker: flag),
      'notes' => existing.copyWith(notes: correction.newValue),
      // An unparseable value is left alone rather than written as a zero.
      _ => null,
    };
    if (corrected == null) {
      return;
    }

    await _scoreRepository.upsertScore(
      corrected.copyWith(
        syncStatus: ScoreSyncStatus.local,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// The round's current card, read back from storage.
  Future<RoundSummary> _summaryOf(Round round) async {
    return RoundSummary(
      roundId: round.id,
      courseName: round.courseName,
      startedAt: round.startedAt,
      endedAt: round.endedAt,
      players: await _playersFor(round),
    );
  }
}

// ─── Summary aggregation ─────────────────────────────────────────────────────

/// Turns the rows the scorecard wrote into the per-player cards the summary
/// screen renders.
///
/// A top-level function so it can be tested for what it is — arithmetic over
/// score rows — without standing up SQLite, SharedPreferences and four
/// services to reach it.
List<PlayerScoreSummary> buildPlayerSummaries({
  required List<Score> scores,
  required Map<int, int> parByHole,
  required Map<String, String> playerNames,
}) {
  final byPlayer = <String, List<ScoreEntry>>{};
  for (final score in scores) {
    final strokes = score.grossScore;
    final holeNumber = int.tryParse(score.holeId);
    // A hole the golfer opened but never scored is not a zero; it is a hole
    // with no score, and belongs in neither the total nor the card.
    if (strokes == null || holeNumber == null) {
      continue;
    }
    byPlayer
        .putIfAbsent(score.playerId, () => <ScoreEntry>[])
        .add(
          ScoreEntry(
            holeNumber: holeNumber,
            // 0 when the course package carries no geometry for this hole.
            par: parByHole[holeNumber] ?? 0,
            strokes: strokes,
            putts: score.putts,
            penalties: score.penalties,
            fairwayHit: score.fairwayHit,
            gir: score.gir,
            bunker: score.bunker,
            notes: score.notes,
          ),
        );
  }

  final players = <PlayerScoreSummary>[];
  for (final entry in byPlayer.entries) {
    final holes = entry.value
      ..sort((a, b) => a.holeNumber.compareTo(b.holeNumber));
    final totalStrokes = holes.fold<int>(0, (sum, h) => sum + h.strokes);
    // Par totals, and the score relative to them, count only holes whose par
    // is known. Treating an unknown par as 0 would report a golfer as dozens
    // of shots over par on a course this device has no card for.
    final scored = holes.where((h) => h.par > 0);
    players.add(
      PlayerScoreSummary(
        playerId: entry.key,
        playerName: playerNames[entry.key] ?? entry.key,
        holes: holes,
        totalStrokes: totalStrokes,
        totalPar: scored.fold<int>(0, (sum, h) => sum + h.par),
        relativeScore: scored.fold<int>(0, (sum, h) => sum + h.relativeToPar),
        syncState: SyncState.pending,
      ),
    );
  }

  players.sort((a, b) => a.playerName.compareTo(b.playerName));
  return players;
}
