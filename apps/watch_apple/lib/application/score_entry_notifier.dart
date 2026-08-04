// Score Entry Notifier — VSP Watch Apple App
//
// State management for score entry flow.
// Manages player selection, score input, and sync queue.
//
// Story 10.1 — Slice 3: Quick Score Entry

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/watch_round_session.dart';
import '../../infrastructure/local/watch_score_repository.dart';

// ─── Events ─────────────────────────────────────────────────────────────────

abstract class ScoreEntryEvent extends Equatable {
  const ScoreEntryEvent();

  @override
  List<Object?> get props => [];
}

class ScoreEntryPlayerSelected extends ScoreEntryEvent {
  final String playerId;
  const ScoreEntryPlayerSelected(this.playerId);

  @override
  List<Object?> get props => [playerId];
}

class ScoreEntryScoreChanged extends ScoreEntryEvent {
  final int score;
  const ScoreEntryScoreChanged(this.score);

  @override
  List<Object?> get props => [score];
}

class ScoreEntrySubmitted extends ScoreEntryEvent {
  const ScoreEntrySubmitted();
}

class ScoreEntryCancelled extends ScoreEntryEvent {
  const ScoreEntryCancelled();
}

class ScoreEntryLoaded extends ScoreEntryEvent {
  final WatchRoundSession session;
  const ScoreEntryLoaded(this.session);

  @override
  List<Object?> get props => [session];
}

class ScoreEntrySyncQueued extends ScoreEntryEvent {
  const ScoreEntrySyncQueued();
}

// ─── State ──────────────────────────────────────────────────────────────────

class ScoreEntryState extends Equatable {
  final String? selectedPlayerId;
  final int? enteredScore;
  final bool isSubmitting;
  final bool isSaved;
  final String? errorMessage;
  final WatchRoundSession? session;
  final List<WatchScoreEntry> pendingSync;

  const ScoreEntryState({
    this.selectedPlayerId,
    this.enteredScore,
    this.isSubmitting = false,
    this.isSaved = false,
    this.errorMessage,
    this.session,
    this.pendingSync = const [],
  });

  ScoreEntryState copyWith({
    String? selectedPlayerId,
    int? enteredScore,
    bool? isSubmitting,
    bool? isSaved,
    String? errorMessage,
    WatchRoundSession? session,
    List<WatchScoreEntry>? pendingSync,
  }) {
    return ScoreEntryState(
      selectedPlayerId: selectedPlayerId ?? this.selectedPlayerId,
      enteredScore: enteredScore ?? this.enteredScore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSaved: isSaved ?? this.isSaved,
      errorMessage: errorMessage,
      session: session ?? this.session,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  List<Object?> get props => [
        selectedPlayerId,
        enteredScore,
        isSubmitting,
        isSaved,
        errorMessage,
        session,
        pendingSync,
      ];
}

// ─── Notifier/Cubit ─────────────────────────────────────────────────────────

class ScoreEntryNotifier extends Cubit<ScoreEntryState> {
  final WatchScoreRepository _repository;
  final Uuid _uuid = const Uuid();

  ScoreEntryNotifier({
    WatchScoreRepository? repository,
  })  : _repository = repository ?? WatchScoreRepository(),
        super(const ScoreEntryState());

  void loadSession(WatchRoundSession session) {
    // Auto-select first player if none selected
    String? playerId = state.selectedPlayerId;
    if (playerId == null && session.scores.isNotEmpty) {
      playerId = session.scores.first.playerId;
    } else if (playerId == null) {
      playerId = 'player_1'; // Default player ID
    }

    emit(state.copyWith(
      session: session,
      selectedPlayerId: playerId,
      isSaved: false,
    ));
  }

  void selectPlayer(String playerId) {
    emit(state.copyWith(
      selectedPlayerId: playerId,
      isSaved: false,
    ));
  }

  void updateScore(int score) {
    emit(state.copyWith(
      enteredScore: score,
      isSaved: false,
    ));
  }

  Future<void> submitScore() async {
    if (state.selectedPlayerId == null || state.enteredScore == null) {
      emit(state.copyWith(
        errorMessage: 'Please select a player and enter a score',
      ));
      return;
    }

    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    try {
      final entry = WatchScoreEntry(
        id: _uuid.v4(),
        playerId: state.selectedPlayerId!,
        holeNumber: state.session?.currentHole ?? 1,
        grossScore: state.enteredScore,
        enteredAt: DateTime.now(),
        syncStatus: 'local',
      );

      // Save to local repository
      await _repository.saveScoreEntry(entry);

      // Update session with new score
      final updatedSession = state.session?.copyWith(
        scores: [
          ...state.session!.scores,
          WatchHoleScore(
            playerId: entry.playerId,
            holeNumber: entry.holeNumber,
            strokes: entry.grossScore,
            putts: entry.putts,
            penalties: entry.penalties,
            fairwayHit: entry.fairwayHit,
            gir: entry.gir,
            enteredAt: entry.enteredAt,
          ),
        ],
        syncStatus: 'pending',
        updatedAt: DateTime.now(),
      );

      // Get pending sync entries
      final pending = await _repository.getPendingSyncEntries();

      emit(state.copyWith(
        session: updatedSession,
        isSubmitting: false,
        isSaved: true,
        pendingSync: pending,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to save score: $e',
      ));
    }
  }

  void cancel() {
    emit(state.copyWith(
      enteredScore: null,
      isSaved: false,
      errorMessage: null,
    ));
  }

  void clearSavedFlag() {
    emit(state.copyWith(isSaved: false));
  }
}
