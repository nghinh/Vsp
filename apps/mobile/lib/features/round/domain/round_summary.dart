// RoundSummary Model — VSP Mobile App
//
// Summary of a completed round for display on RoundSummaryScreen.
// Per Story 5.5 Slice 2: AC-2 summary display with per-player scorecard, stats, sync state.

import 'score_entry.dart';
import 'sync_state.dart';

/// Per-player score summary for a completed round.
class PlayerScoreSummary {
  final String playerId;
  final String playerName;
  final List<ScoreEntry> holes;
  final int totalStrokes;
  final int totalPar;
  final int relativeScore; // vs par (+/-)
  final SyncState syncState;

  const PlayerScoreSummary({
    required this.playerId,
    required this.playerName,
    required this.holes,
    required this.totalStrokes,
    required this.totalPar,
    required this.relativeScore,
    required this.syncState,
  });

  /// Front 9 total strokes.
  int get frontNineStrokes => holes
      .where((h) => h.holeNumber <= 9)
      .fold(0, (sum, h) => sum + h.strokes);

  /// Back 9 total strokes.
  int get backNineStrokes =>
      holes.where((h) => h.holeNumber > 9).fold(0, (sum, h) => sum + h.strokes);

  /// Fairways hit count (par-4/5 holes only).
  int get fairwaysHit =>
      holes.where((h) => h.par >= 4 && h.fairwayHit == true).length;

  /// Total par-4/5 holes (for fairway % calculation).
  int get par4Or5Count => holes.where((h) => h.par >= 4).length;

  /// GIR count.
  int get girCount => holes.where((h) => h.gir == true).length;

  /// Total putts.
  int get totalPutts => holes.fold(0, (sum, h) => sum + (h.putts ?? 0));

  /// Total penalties.
  int get totalPenalties => holes.fold(0, (sum, h) => sum + (h.penalties ?? 0));

  Map<String, dynamic> toMap() => {
    'playerId': playerId,
    'playerName': playerName,
    'holes': holes.map((h) => h.toMap()).toList(),
    'totalStrokes': totalStrokes,
    'totalPar': totalPar,
    'relativeScore': relativeScore,
    'syncState': syncState.name,
  };

  factory PlayerScoreSummary.fromMap(Map<String, dynamic> map) {
    return PlayerScoreSummary(
      playerId: map['playerId'] as String,
      playerName: map['playerName'] as String,
      holes:
          (map['holes'] as List?)
              ?.map((h) => ScoreEntry.fromMap(h as Map<String, dynamic>))
              .toList() ??
          [],
      totalStrokes: map['totalStrokes'] as int,
      totalPar: map['totalPar'] as int,
      relativeScore: map['relativeScore'] as int,
      syncState: SyncState.values.firstWhere(
        (s) => s.name == map['syncState'],
        orElse: () => SyncState.pending,
      ),
    );
  }
}

/// Summary of a completed round.
class RoundSummary {
  final String roundId;
  final String courseName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<PlayerScoreSummary> players;

  const RoundSummary({
    required this.roundId,
    required this.courseName,
    required this.startedAt,
    this.endedAt,
    required this.players,
  });

  /// Overall sync state — worst state among all players.
  SyncState get overallSyncState {
    if (players.isEmpty) return SyncState.synced;
    return players
        .map((p) => p.syncState)
        .reduce((a, b) => a.index >= b.index ? a : b);
  }

  Map<String, dynamic> toMap() => {
    'roundId': roundId,
    'courseName': courseName,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'players': players.map((p) => p.toMap()).toList(),
  };

  factory RoundSummary.fromMap(Map<String, dynamic> map) {
    return RoundSummary(
      roundId: map['roundId'] as String,
      courseName: map['courseName'] as String,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: map['endedAt'] != null
          ? DateTime.parse(map['endedAt'] as String)
          : null,
      players: (map['players'] as List)
          .map((p) => PlayerScoreSummary.fromMap(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
