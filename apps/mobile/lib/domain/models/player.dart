// Player Model — VSP Mobile App
//
// Participant in a round.
// Stored in vsp_round.db (Story 5.2).
//
// Story 5.1 Slice A: extended with isPrimary and JSON serialization
// for API-level round configuration.

import 'package:equatable/equatable.dart';

/// Player participating in a round (local or from account).
///
/// The primary player is the initiating golfer (self) — position 1 in
/// the [RoundConfig.players] list.
///
/// ## Persistence
/// - SQLite: [toMap] / [fromMap] — uses `is_current_user` column.
/// - API:    [fromJson] / [toJson] — uses `isPrimary` field.
class Player extends Equatable {
  final String id;
  final String name;
  final double? handicap;

  /// True if this is the primary (initiating) player.
  /// Mirrors [isCurrentUser] — see that field for SQLite column mapping.
  final bool isPrimary;

  /// @deprecated Use [isPrimary] instead. Kept for SQLite backward compatibility.
  bool get isCurrentUser => isPrimary;

  const Player({
    required this.id,
    required this.name,
    this.handicap,
    this.isPrimary = false,
  });

  /// Copy with updated fields.
  Player copyWith({
    String? id,
    String? name,
    double? handicap,
    bool? isPrimary,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      handicap: handicap ?? this.handicap,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  // -------------------------------------------------------------------------
  // SQLite persistence (Story 5.2)
  // -------------------------------------------------------------------------

  /// Convert to a Map for SQLite persistence.
  /// Uses `is_current_user` column for backward compatibility.
  Map<String, dynamic> toMap(String roundId) {
    return {
      'id': id,
      'round_id': roundId,
      'name': name,
      'handicap': handicap,
      'is_current_user': isPrimary ? 1 : 0,
    };
  }

  /// Reconstruct from a SQLite row.
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as String,
      name: map['name'] as String,
      handicap: map['handicap'] as double?,
      isPrimary: (map['is_current_user'] as int) == 1,
    );
  }

  // -------------------------------------------------------------------------
  // JSON serialization (Story 5.1 — API round config)
  // -------------------------------------------------------------------------

  /// Parse from API response JSON.
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      handicap: (json['handicap'] as num?)?.toDouble(),
      isPrimary:
          json['isPrimary'] as bool? ??
          json['is_current_user'] as bool? ??
          false,
    );
  }

  /// Convert to JSON for API round creation.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (handicap != null) 'handicap': handicap,
    'isPrimary': isPrimary,
  };

  @override
  List<Object?> get props => [id, name, handicap, isPrimary];
}
