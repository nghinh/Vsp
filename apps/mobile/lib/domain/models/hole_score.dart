// HoleScore Model — VSP Mobile App
//
// Per-hole scoring data for a round.
// Stored in vsp_round.db.
//
// Story 5.2: Persist Round Locally

import 'package:equatable/equatable.dart';

/// Score record for a single hole within a round.
class HoleScore extends Equatable {
  final String id; // UUID
  final String roundId;
  final int holeNumber; // 1-27
  final int par; // 3-6
  final int strokes;
  final int? putts;
  final int? penalties;
  final bool? fairwayHit;
  final bool? gir; // green-in-regulation
  final String? clubUsed;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HoleScore({
    required this.id,
    required this.roundId,
    required this.holeNumber,
    required this.par,
    required this.strokes,
    this.putts,
    this.penalties,
    this.fairwayHit,
    this.gir,
    this.clubUsed,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Net score relative to par (positive = over par, negative = under par).
  int get scoreToPar => strokes - par;

  /// Copy with updated fields.
  HoleScore copyWith({
    String? id,
    String? roundId,
    int? holeNumber,
    int? par,
    int? strokes,
    int? putts,
    int? penalties,
    bool? fairwayHit,
    bool? gir,
    String? clubUsed,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HoleScore(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      holeNumber: holeNumber ?? this.holeNumber,
      par: par ?? this.par,
      strokes: strokes ?? this.strokes,
      putts: putts ?? this.putts,
      penalties: penalties ?? this.penalties,
      fairwayHit: fairwayHit ?? this.fairwayHit,
      gir: gir ?? this.gir,
      clubUsed: clubUsed ?? this.clubUsed,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'round_id': roundId,
      'hole_number': holeNumber,
      'par': par,
      'strokes': strokes,
      'putts': putts,
      'penalties': penalties,
      'fairway_hit': fairwayHit == null ? null : (fairwayHit! ? 1 : 0),
      'gir': gir == null ? null : (gir! ? 1 : 0),
      'club_used': clubUsed,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Reconstruct from a SQLite row.
  factory HoleScore.fromMap(Map<String, dynamic> map) {
    return HoleScore(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      holeNumber: (map['hole_number'] as num).toInt(),
      par: (map['par'] as num).toInt(),
      strokes: (map['strokes'] as num).toInt(),
      putts: (map['putts'] as num?)?.toInt(),
      penalties: (map['penalties'] as num?)?.toInt(),
      fairwayHit: map['fairway_hit'] != null
          ? ((map['fairway_hit'] as num).toInt()) == 1
          : null,
      gir: map['gir'] != null ? ((map['gir'] as num).toInt()) == 1 : null,
      clubUsed: map['club_used'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    roundId,
    holeNumber,
    par,
    strokes,
    putts,
    penalties,
    fairwayHit,
    gir,
    clubUsed,
    notes,
    createdAt,
    updatedAt,
  ];
}
