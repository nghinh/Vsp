// Flight Model — VSP Mobile App
//
// Groups 1–4 players within a round for simultaneous play.
// A round may have multiple flights (e.g., shotgun start).
//
// Story 5.3 — Slice 1: Domain Models

import 'package:equatable/equatable.dart';

/// A group of players playing together within a round.
///
/// A [Flight] belongs to exactly one [Round] and contains 1–4 players.
///
// TODO(5.1 coord): Round model should have flightIds: List<String>.
// Until Round is updated, Flight stores roundId as a String reference.
class Flight extends Equatable {
  /// Unique identifier (UUID string).
  final String id;

  /// Reference to the parent round ID.
  final String roundId;

  /// 1-based flight index within the round day.
  /// E.g., flight 1 of the day, flight 2 of the day.
  final int flightIndex;

  /// Player IDs in this flight (1–4 players).
  final List<String> playerIds;

  /// When this flight was created.
  final DateTime createdAt;

  /// When this flight was last updated.
  final DateTime updatedAt;

  const Flight({
    required this.id,
    required this.roundId,
    required this.flightIndex,
    required this.playerIds,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True if this flight has the maximum number of players (4).
  bool get isFull => playerIds.length >= 4;

  /// True if this flight has the minimum number of players (1).
  bool get isEmpty => playerIds.isEmpty;

  /// Number of players currently in this flight.
  int get playerCount => playerIds.length;

  /// Copy with updated fields.
  Flight copyWith({
    String? id,
    String? roundId,
    int? flightIndex,
    List<String>? playerIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Flight(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      flightIndex: flightIndex ?? this.flightIndex,
      playerIds: playerIds ?? this.playerIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Parse from SQLite row or API response.
  factory Flight.fromMap(Map<String, dynamic> map) {
    return Flight(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      flightIndex: (map['flight_index'] as num).toInt(),
      playerIds: (map['player_ids'] as String).isNotEmpty
          ? (map['player_ids'] as String).split(',')
          : <String>[],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'round_id': roundId,
      'flight_index': flightIndex,
      'player_ids': playerIds.join(','),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Parse from API JSON (DTO format).
  factory Flight.fromJson(Map<String, dynamic> json) {
    return Flight(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      flightIndex: (json['flightIndex'] as num).toInt(),
      playerIds: (json['playerIds'] as List<dynamic>? ?? const []).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roundId': roundId,
    'flightIndex': flightIndex,
    'playerIds': playerIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    roundId,
    flightIndex,
    playerIds,
    createdAt,
    updatedAt,
  ];
}
