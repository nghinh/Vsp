// Scorecard State — VSP Mobile App
//
// Extended state classes for the full scorecard screen.
// Uses domain ScorecardState as the core state model.
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:equatable/equatable.dart';

import '../../../domain/models/score.dart';
import '../../../domain/models/sync_status.dart';

/// Screen-level state for the scorecard.
class ScorecardScreenState extends Equatable {
  /// The underlying scorecard state model.
  final String flightId;

  /// Ordered list of hole IDs in this round.
  final List<String> holeIds;

  /// Map of holeId → par for display.
  final Map<String, int> holePars;

  /// Score matrix: playerId → holeId → Score.
  final Map<String, Map<String, Score>> scores;

  /// 0-based index of the currently displayed hole.
  final int currentHoleIndex;

  /// IDs of players in this flight.
  final List<String> playerIds;

  /// Names of players (playerId → name).
  final Map<String, String> playerNames;

  /// Tournament mode flag.
  final bool isTournamentMode;

  /// True if the scorecard is loading.
  final bool isLoading;

  /// Error message if loading failed.
  final String? errorMessage;

  /// Overall sync status for the scorecard.
  final bool isOffline;

  /// Aggregated sync status for the round (pending/syncing/synced/failed).
  final SyncStatus syncStatus;

  const ScorecardScreenState({
    required this.flightId,
    required this.holeIds,
    this.holePars = const {},
    this.scores = const {},
    this.currentHoleIndex = 0,
    this.playerIds = const [],
    this.playerNames = const {},
    this.isTournamentMode = false,
    this.isLoading = false,
    this.errorMessage,
    this.isOffline = false,
    this.syncStatus = SyncStatus.synced,
  });

  String? get currentHoleId =>
      holeIds.isNotEmpty && currentHoleIndex < holeIds.length
      ? holeIds[currentHoleIndex]
      : null;

  int get currentHoleNumber => currentHoleIndex + 1;

  bool get canGoBack => currentHoleIndex > 0;
  bool get canGoForward => currentHoleIndex < holeIds.length - 1;
  bool get isLastHole =>
      holeIds.isNotEmpty && currentHoleIndex == holeIds.length - 1;

  int get totalHoles => holeIds.length;

  int? get currentPar => currentHoleId != null ? holePars[currentHoleId] : null;

  /// Gets the score for a specific player and hole.
  Score? getScore(String playerId, String holeId) {
    return scores[playerId]?[holeId];
  }

  /// Gets the gross score for a specific player and hole.
  int? getGrossScore(String playerId, String holeId) {
    return scores[playerId]?[holeId]?.grossScore;
  }

  /// Number of players who have entered a score for the current hole.
  int get currentHoleFilledCount {
    final holeId = currentHoleId;
    if (holeId == null) return 0;
    int count = 0;
    for (final playerId in playerIds) {
      if (getGrossScore(playerId, holeId) != null) {
        count++;
      }
    }
    return count;
  }

  ScorecardScreenState copyWith({
    String? flightId,
    List<String>? holeIds,
    Map<String, int>? holePars,
    Map<String, Map<String, Score>>? scores,
    int? currentHoleIndex,
    List<String>? playerIds,
    Map<String, String>? playerNames,
    bool? isTournamentMode,
    bool? isLoading,
    String? errorMessage,
    bool? isOffline,
    SyncStatus? syncStatus,
  }) {
    return ScorecardScreenState(
      flightId: flightId ?? this.flightId,
      holeIds: holeIds ?? this.holeIds,
      holePars: holePars ?? this.holePars,
      scores: scores ?? this.scores,
      currentHoleIndex: currentHoleIndex ?? this.currentHoleIndex,
      playerIds: playerIds ?? this.playerIds,
      playerNames: playerNames ?? this.playerNames,
      isTournamentMode: isTournamentMode ?? this.isTournamentMode,
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  List<Object?> get props => [
    flightId,
    holeIds,
    holePars,
    scores,
    currentHoleIndex,
    playerIds,
    playerNames,
    isTournamentMode,
    isLoading,
    errorMessage,
    isOffline,
    syncStatus,
  ];
}
