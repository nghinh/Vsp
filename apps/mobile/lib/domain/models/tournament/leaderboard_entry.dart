// LeaderboardEntry Model — VSP Mobile App
//
// Per Story 12.1 AC: Live leaderboard with real-time score updates.
//
// Story 12.1 Slice F

import 'package:equatable/equatable.dart';

/// A single entry in the tournament leaderboard.
class LeaderboardEntry extends Equatable {
  final int rank;
  final bool isTied;
  final int playerId;
  final String? playerName; // denormalized for display
  final int? score; // total strokes — null if not yet started
  final int? scoreToPar; // relative to par — null if not applicable
  final String status; // e.g., "REGISTERED", "CONFIRMED"
  final String? flightId;
  final int? roundNumber; // for multi-round tournaments

  const LeaderboardEntry({
    required this.rank,
    this.isTied = false,
    required this.playerId,
    this.playerName,
    this.score,
    this.scoreToPar,
    required this.status,
    this.flightId,
    this.roundNumber,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int? ?? 0,
      isTied: json['tied'] as bool? ?? false,
      playerId: json['playerId'] is String
          ? int.parse(json['playerId'] as String)
          : json['playerId'] as int,
      playerName: json['playerName'] as String?,
      score: json['score'] as int?,
      scoreToPar: json['scoreToPar'] as int?,
      status: json['status'] as String? ?? 'UNKNOWN',
      flightId: json['flightId'] as String?,
      roundNumber: json['roundNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'tied': isTied,
    'playerId': playerId,
    'playerName': playerName,
    'score': score,
    'scoreToPar': scoreToPar,
    'status': status,
    'flightId': flightId,
    'roundNumber': roundNumber,
  };

  @override
  List<Object?> get props => [
    rank,
    isTied,
    playerId,
    playerName,
    score,
    scoreToPar,
    status,
    flightId,
    roundNumber,
  ];
}

/// Full leaderboard response for a tournament.
class Leaderboard extends Equatable {
  final String tournamentId;
  final int version;
  final DateTime updatedAt;
  final List<LeaderboardEntry> entries;

  const Leaderboard({
    required this.tournamentId,
    required this.version,
    required this.updatedAt,
    required this.entries,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    return Leaderboard(
      tournamentId: json['tournamentId'] as String,
      version: json['version'] as int? ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// True if this leaderboard has any entries.
  bool get hasEntries => entries.isNotEmpty;

  /// Find the entry for a specific player.
  LeaderboardEntry? entryForPlayer(int playerId) {
    try {
      return entries.firstWhere((e) => e.playerId == playerId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [tournamentId, version, updatedAt, entries];
}
