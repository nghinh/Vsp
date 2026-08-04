// ScorecardState Model — VSP Mobile App
//
// UI state model for the scorecard entry screen.
// NOT persisted — managed by ScorecardCubit.
//
// Story 5.3 — Slice 1: Domain Models

import 'package:equatable/equatable.dart';

import 'score.dart';

/// UI state for the scorecard screen.
///
/// Manages the current flight, hole navigation, and score matrix
/// for up to 4 players across all holes in a round.
///
/// Not persisted directly — scores are persisted via [Score.toMap]
/// through the ScoreRepository. This state is rebuilt from SQLite
/// on app restart (via story 5.2 recovery path).
class ScorecardState extends Equatable {
  /// The active flight for this scorecard.
  final String flightId;

  /// Ordered list of hole IDs (or hole numbers) in this round.
  /// Typically 18 holes, but 9-hole rounds are also supported.
  final List<String> holeIds;

  /// Score matrix: outer key = playerId, inner key = holeId.
  /// Only contains entries for holes that have been started.
  final Map<String, Map<String, Score>> scores;

  /// 0-based index of the currently displayed hole.
  final int currentHoleIndex;

  /// Tournament mode flag — when true, certain features may be restricted.
  /// Set from round configuration at scorecard initialization.
  final bool isTournamentMode;

  const ScorecardState({
    required this.flightId,
    required this.holeIds,
    required this.scores,
    this.currentHoleIndex = 0,
    this.isTournamentMode = false,
  });

  /// The hole ID of the currently displayed hole.
  String? get currentHoleId =>
      holeIds.isNotEmpty && currentHoleIndex < holeIds.length
      ? holeIds[currentHoleIndex]
      : null;

  /// True if we can navigate to the previous hole.
  bool get canGoBack => currentHoleIndex > 0;

  /// True if we can navigate to the next hole.
  bool get canGoForward => currentHoleIndex < holeIds.length - 1;

  /// Total number of holes in this scorecard.
  int get totalHoles => holeIds.length;

  /// Current hole number (1-based for display).
  int get currentHoleNumber => currentHoleIndex + 1;

  /// All player IDs that have scores in this scorecard.
  Set<String> get playerIds => scores.keys.toSet();

  /// Number of players in this scorecard.
  int get playerCount => playerIds.length;

  /// Gets the score for a specific player and hole.
  Score? getScore(String playerId, String holeId) {
    return scores[playerId]?[holeId];
  }

  /// Gets all scores for a specific player.
  Map<String, Score>? getPlayerScores(String playerId) {
    return scores[playerId];
  }

  /// Gets the gross score for a specific player and hole.
  int? getGrossScore(String playerId, String holeId) {
    return scores[playerId]?[holeId]?.grossScore;
  }

  /// True if all players have entered a score for the current hole.
  bool get currentHoleComplete {
    if (playerIds.isEmpty) return false;
    for (final playerId in playerIds) {
      if (getGrossScore(playerId, currentHoleId!) == null) {
        return false;
      }
    }
    return true;
  }

  /// Number of players who have entered a score for the current hole.
  int get currentHoleFilledCount {
    if (currentHoleId == null) return 0;
    int count = 0;
    for (final playerId in playerIds) {
      if (getGrossScore(playerId, currentHoleId!) != null) {
        count++;
      }
    }
    return count;
  }

  /// Creates an initial empty scorecard state for a new round.
  factory ScorecardState.initial({
    required String flightId,
    required List<String> holeIds,
    required List<String> playerIds,
    bool isTournamentMode = false,
  }) {
    // Initialize empty scores map for each player
    final scores = <String, Map<String, Score>>{};
    for (final playerId in playerIds) {
      scores[playerId] = {};
    }
    return ScorecardState(
      flightId: flightId,
      holeIds: holeIds,
      scores: scores,
      currentHoleIndex: 0,
      isTournamentMode: isTournamentMode,
    );
  }

  /// Copy with updated fields.
  ScorecardState copyWith({
    String? flightId,
    List<String>? holeIds,
    Map<String, Map<String, Score>>? scores,
    int? currentHoleIndex,
    bool? isTournamentMode,
  }) {
    return ScorecardState(
      flightId: flightId ?? this.flightId,
      holeIds: holeIds ?? this.holeIds,
      scores: scores ?? this.scores,
      currentHoleIndex: currentHoleIndex ?? this.currentHoleIndex,
      isTournamentMode: isTournamentMode ?? this.isTournamentMode,
    );
  }

  /// Returns a copy with a score updated for a specific player and hole.
  ScorecardState withScore(Score score) {
    final playerScores = Map<String, Score>.from(scores[score.playerId] ?? {});
    playerScores[score.holeId] = score;

    final newScores = Map<String, Map<String, Score>>.from(scores);
    newScores[score.playerId] = playerScores;

    return copyWith(scores: newScores);
  }

  /// Returns a copy with navigation moved to the next hole.
  ScorecardState moveToNextHole() {
    if (!canGoForward) return this;
    return copyWith(currentHoleIndex: currentHoleIndex + 1);
  }

  /// Returns a copy with navigation moved to the previous hole.
  ScorecardState moveToPreviousHole() {
    if (!canGoBack) return this;
    return copyWith(currentHoleIndex: currentHoleIndex - 1);
  }

  /// Returns a copy with navigation moved to a specific hole index.
  ScorecardState moveToHoleIndex(int index) {
    if (index < 0 || index >= holeIds.length) return this;
    return copyWith(currentHoleIndex: index);
  }

  @override
  List<Object?> get props => [
    flightId,
    holeIds,
    scores,
    currentHoleIndex,
    isTournamentMode,
  ];
}
