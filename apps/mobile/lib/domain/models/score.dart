// Score Model — VSP Mobile App
//
// Per-hole per-player score data for a flight.
// Constraint: exactly one Score per (flightId, holeId, playerId) tuple.
//
// Story 5.3 — Slice 1: Domain Models

import 'package:equatable/equatable.dart';

import 'score_value_objects.dart';

/// A score record for one player on one hole within a flight.
///
/// Supports progressive disclosure fields (putts, penalties, fairway, GIR, bunker, notes)
/// and local-first sync status metadata per architecture §8.3.
class Score extends Equatable {
  /// Unique identifier (UUID string).
  final String id;

  /// Reference to the parent flight ID.
  final String flightId;

  /// Reference to the hole (holeId from story 3.1 geometry model).
  /// Type: String to allow UUID or integer hole identifiers.
  final String holeId;

  /// Reference to the player ID.
  final String playerId;

  // ─── Primary entry ─────────────────────────────────────────────────────────

  /// Gross strokes taken on this hole. null until entered.
  /// Valid range: 1–30 per validation rules.
  final int? grossScore;

  // ─── Progressive disclosure fields ─────────────────────────────────────────

  /// Number of putts (0–15). null until entered.
  final int? putts;

  /// Number of penalty strokes (0–10). null until entered.
  final int? penalties;

  /// Whether the fairway was hit (par-4/5 only; null for par-3 = N/A).
  final bool? fairwayHit;

  /// Green in regulation: true if reached green in regulation.
  final bool? gir;

  /// Whether the ball was hit from a bunker.
  final bool? bunker;

  /// Free-text notes for this hole (max 200 chars).
  final String? notes;

  // ─── Metadata ─────────────────────────────────────────────────────────────

  /// When the score was first entered. null if not yet started.
  final DateTime? enteredAt;

  /// Local-first sync status.
  final ScoreSyncStatus syncStatus;

  /// Optimistic concurrency version counter.
  final int version;

  /// When this score was last modified.
  final DateTime updatedAt;

  const Score({
    required this.id,
    required this.flightId,
    required this.holeId,
    required this.playerId,
    this.grossScore,
    this.putts,
    this.penalties,
    this.fairwayHit,
    this.gir,
    this.bunker,
    this.notes,
    this.enteredAt,
    this.syncStatus = ScoreSyncStatus.local,
    this.version = 1,
    required this.updatedAt,
  });

  // ─── Derived state ─────────────────────────────────────────────────────────

  /// True if gross score has been entered.
  bool get hasScore => grossScore != null;

  /// True if this score is complete (gross entered and all progressive fields set).
  bool get isComplete =>
      grossScore != null &&
      putts != null &&
      penalties != null &&
      fairwayHit != null &&
      gir != null &&
      bunker != null;

  /// Number of progressive fields that have been entered.
  int get filledFieldCount {
    int count = 0;
    if (putts != null) count++;
    if (penalties != null) count++;
    if (fairwayHit != null) count++;
    if (gir != null) count++;
    if (bunker != null) count++;
    if (notes != null && notes!.isNotEmpty) count++;
    return count;
  }

  /// Progressive disclosure state for UI rendering.
  ScoreEntryState get entryState {
    if (!hasScore) return ScoreEntryState.notStarted;
    if (isComplete) return ScoreEntryState.complete;
    return ScoreEntryState.grossEntered;
  }

  // ─── Validation ─────────────────────────────────────────────────────────────

  /// Validates all fields and returns a list of errors (empty = valid).
  List<String> validate() {
    final errors = <String>[];

    final grossValidation = GrossScoreValidator.validate(grossScore);
    if (!grossValidation.isValid) errors.add(grossValidation.errorMessage!);

    final puttsValidation = PuttsValidator.validate(putts);
    if (!puttsValidation.isValid) errors.add(puttsValidation.errorMessage!);

    final penaltiesValidation = PenaltiesValidator.validate(penalties);
    if (!penaltiesValidation.isValid)
      errors.add(penaltiesValidation.errorMessage!);

    if (notes != null && notes!.length > 200) {
      errors.add('Notes must be 200 characters or fewer');
    }

    return errors;
  }

  /// True if all validations pass.
  bool get isValid => validate().isEmpty;

  // ─── Copy ──────────────────────────────────────────────────────────────────

  /// Copy with updated fields.
  Score copyWith({
    String? id,
    String? flightId,
    String? holeId,
    String? playerId,
    int? grossScore,
    int? putts,
    int? penalties,
    bool? fairwayHit,
    bool? gir,
    bool? bunker,
    String? notes,
    DateTime? enteredAt,
    ScoreSyncStatus? syncStatus,
    int? version,
    DateTime? updatedAt,
    bool clearGrossScore = false,
    bool clearPutts = false,
    bool clearPenalties = false,
    bool clearFairwayHit = false,
    bool clearGir = false,
    bool clearBunker = false,
    bool clearNotes = false,
  }) {
    return Score(
      id: id ?? this.id,
      flightId: flightId ?? this.flightId,
      holeId: holeId ?? this.holeId,
      playerId: playerId ?? this.playerId,
      grossScore: clearGrossScore ? null : (grossScore ?? this.grossScore),
      putts: clearPutts ? null : (putts ?? this.putts),
      penalties: clearPenalties ? null : (penalties ?? this.penalties),
      fairwayHit: clearFairwayHit ? null : (fairwayHit ?? this.fairwayHit),
      gir: clearGir ? null : (gir ?? this.gir),
      bunker: clearBunker ? null : (bunker ?? this.bunker),
      notes: clearNotes ? null : (notes ?? this.notes),
      enteredAt: enteredAt ?? this.enteredAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── Serialization ─────────────────────────────────────────────────────────

  /// Convert to a Map for SQLite persistence.
  ///
  /// Nullable booleans are stored as integers: 1=true, 0=false, null=unset.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'flight_id': flightId,
      'hole_id': holeId,
      'player_id': playerId,
      'gross_score': grossScore,
      'putts': putts,
      'penalties': penalties,
      'fairway_hit': fairwayHit == null ? null : (fairwayHit! ? 1 : 0),
      'gir': gir == null ? null : (gir! ? 1 : 0),
      'bunker': bunker == null ? null : (bunker! ? 1 : 0),
      'notes': notes,
      'entered_at': enteredAt?.toUtc().toIso8601String(),
      'sync_status': syncStatus.name,
      'version': version,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Reconstruct from a SQLite row.
  factory Score.fromMap(Map<String, dynamic> map) {
    return Score(
      id: map['id'] as String,
      flightId: map['flight_id'] as String,
      holeId: map['hole_id'] as String,
      playerId: map['player_id'] as String,
      grossScore: map['gross_score'] as int?,
      putts: map['putts'] as int?,
      penalties: map['penalties'] as int?,
      fairwayHit: map['fairway_hit'] != null
          ? (map['fairway_hit'] as int) == 1
          : null,
      gir: map['gir'] != null ? (map['gir'] as int) == 1 : null,
      bunker: map['bunker'] != null ? (map['bunker'] as int) == 1 : null,
      notes: map['notes'] as String?,
      enteredAt: map['entered_at'] != null
          ? DateTime.parse(map['entered_at'] as String)
          : null,
      syncStatus: ScoreSyncStatus.fromString(
        map['sync_status'] as String? ?? 'local',
      ),
      version: map['version'] as int? ?? 1,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Parse from API JSON (DTO format).
  factory Score.fromJson(Map<String, dynamic> json) {
    return Score(
      id: json['id'] as String,
      flightId: json['flightId'] as String,
      holeId: json['holeId'] as String,
      playerId: json['playerId'] as String,
      grossScore: json['grossScore'] as int?,
      putts: json['putts'] as int?,
      penalties: json['penalties'] as int?,
      fairwayHit: json['fairwayHit'] as bool?,
      gir: json['gir'] as bool?,
      bunker: json['bunker'] as bool?,
      notes: json['notes'] as String?,
      enteredAt: json['enteredAt'] != null
          ? DateTime.parse(json['enteredAt'] as String)
          : null,
      syncStatus: ScoreSyncStatus.fromString(
        json['syncStatus'] as String? ?? 'local',
      ),
      version: json['version'] as int? ?? 1,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'flightId': flightId,
    'holeId': holeId,
    'playerId': playerId,
    'grossScore': grossScore,
    'putts': putts,
    'penalties': penalties,
    'fairwayHit': fairwayHit,
    'gir': gir,
    'bunker': bunker,
    'notes': notes,
    'enteredAt': enteredAt?.toIso8601String(),
    'syncStatus': syncStatus.name,
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    flightId,
    holeId,
    playerId,
    grossScore,
    putts,
    penalties,
    fairwayHit,
    gir,
    bunker,
    notes,
    enteredAt,
    syncStatus,
    version,
    updatedAt,
  ];
}
