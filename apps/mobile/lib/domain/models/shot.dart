// Shot Model — VSP Mobile App
//
// Local-first shot entity with 22 canonical fields.
// Per Story 10.3: Track Shots Manually.
//
// Stores start/end GPS location, club, lie, distance, conditions,
// result, source, confidence, and sync metadata.
//
// Local persistence: vsp_shots.db (separate from vsp_round.db).

import 'package:equatable/equatable.dart';

import 'sync_status.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

/// Physical lie of the ball when the shot ended.
enum ShotLie {
  teebox,
  fairway,
  rough,
  bunker,
  water,
  penalty,
  green,
  putt,
  outOfBounds,
  cartPath,
  nativeRough,
  primaryRough,
  secondaryRough,
  wasteBunker,
  desert,
  other;

  static ShotLie fromString(String? value) {
    if (value == null) return ShotLie.other;
    final normalized = _normalize(value);
    return ShotLie.values.firstWhere(
      (e) => _normalize(e.name) == normalized,
      orElse: () => ShotLie.other,
    );
  }

  static String _normalize(String value) {
    return value.replaceAll('-', '').replaceAll('_', '').toLowerCase();
  }

  String toApiValue() {
    switch (this) {
      case ShotLie.teebox:
        return 'tee_box';
      case ShotLie.fairway:
        return 'fairway';
      case ShotLie.rough:
        return 'rough';
      case ShotLie.bunker:
        return 'bunker';
      case ShotLie.water:
        return 'water';
      case ShotLie.penalty:
        return 'penalty';
      case ShotLie.green:
        return 'green';
      case ShotLie.putt:
        return 'putt';
      case ShotLie.outOfBounds:
        return 'out_of_bounds';
      case ShotLie.cartPath:
        return 'cart_path';
      case ShotLie.nativeRough:
        return 'native_rough';
      case ShotLie.primaryRough:
        return 'primary_rough';
      case ShotLie.secondaryRough:
        return 'secondary_rough';
      case ShotLie.wasteBunker:
        return 'waste_bunker';
      case ShotLie.desert:
        return 'desert';
      case ShotLie.other:
        return 'other';
    }
  }
}

/// Outcome of the shot — what happened after the ball came to rest.
enum ShotResult {
  fairwayHit,
  greenHit,
  inBunker,
  inWater,
  outOfBounds,
  penalty,
  mulligan,
  provisional,
  scrambleSave,
  chipIn,
  holeOut,
  inTheHole,
  hitL,
  hitSlice,
  hitPull,
  hitPush,
  hitHook,
  hitThin,
  hitHeavy,
  whiff,
  unknown;

  static ShotResult fromString(String? value) {
    if (value == null) return ShotResult.unknown;
    final normalized = _normalize(value);
    return ShotResult.values.firstWhere(
      (e) => _normalize(e.name) == normalized,
      orElse: () => ShotResult.unknown,
    );
  }

  static String _normalize(String value) {
    return value.replaceAll('-', '').replaceAll('_', '').toLowerCase();
  }

  String toApiValue() {
    switch (this) {
      case ShotResult.fairwayHit:
        return 'fairway_hit';
      case ShotResult.greenHit:
        return 'green_hit';
      case ShotResult.inBunker:
        return 'in_bunker';
      case ShotResult.inWater:
        return 'in_water';
      case ShotResult.outOfBounds:
        return 'out_of_bounds';
      case ShotResult.penalty:
        return 'penalty';
      case ShotResult.mulligan:
        return 'mulligan';
      case ShotResult.provisional:
        return 'provisional';
      case ShotResult.scrambleSave:
        return 'scramble_save';
      case ShotResult.chipIn:
        return 'chip_in';
      case ShotResult.holeOut:
        return 'hole_out';
      case ShotResult.inTheHole:
        return 'in_the_hole';
      case ShotResult.hitL:
        return 'hit_L';
      case ShotResult.hitSlice:
        return 'hit_slice';
      case ShotResult.hitPull:
        return 'hit_pull';
      case ShotResult.hitPush:
        return 'hit_push';
      case ShotResult.hitHook:
        return 'hit_hook';
      case ShotResult.hitThin:
        return 'hit_thin';
      case ShotResult.hitHeavy:
        return 'hit_heavy';
      case ShotResult.whiff:
        return 'whiff';
      case ShotResult.unknown:
        return 'unknown';
    }
  }
}

/// How the shot was created.
enum ShotSource {
  manual,
  detected,
  corrected;

  static ShotSource fromString(String? value) {
    if (value == null) return ShotSource.manual;
    return ShotSource.values.firstWhere(
      (e) => e.name == (value ?? '').toLowerCase(),
      orElse: () => ShotSource.manual,
    );
  }
}

// ─── Shot Entity ──────────────────────────────────────────────────────────────

/// Shot entity — represents a single golf shot within a round.
///
/// Per Story 10.3: Track Shots Manually.
/// 22 canonical fields covering start/end location, club, lie, distance,
/// conditions, result, source, confidence, and sync metadata.
class Shot extends Equatable {
  // ─── Identity ─────────────────────────────────────────────────────────────

  final String id; // UUID string

  /// Round this shot belongs to.
  final String roundId;

  /// Flight (group of players) this shot belongs to.
  final String flightId;

  /// Player account ID who owns this shot.
  final String playerId;

  // ─── Shot Identity ────────────────────────────────────────────────────────

  /// Hole number (1–18 for standard rounds; up to 27 for modified).
  final int holeNumber;

  /// Per-hole shot sequence (1 = first shot, 2 = second, etc.).
  final int shotNumber;

  /// Club used for this shot (FK to Club). Null until assigned.
  final String? clubId;

  // ─── Temporal ───────────────────────────────────────────────────────────

  /// When the shot was started (GPS lock acquired).
  final DateTime startedAt;

  /// When the shot was ended (GPS lock on ball at rest). Null if still active.
  final DateTime? endedAt;

  // ─── Spatial (GeoJSON Point as JSON string) ─────────────────────────────

  /// Start location as GeoJSON Point string: {"type":"Point","coordinates":[lon,lat,elev?]}.
  final String? startLocation;

  /// End location as GeoJSON Point string.
  final String? endLocation;

  // ─── Lie / Distance ────────────────────────────────────────────────────

  /// Physical lie of the ball at rest.
  final ShotLie? lie;

  /// Shot distance in yards (calculated from start→end location).
  final double? distanceYards;

  /// Shot distance in meters.
  final double? distanceMeters;

  /// Conditions snapshot at shot time (JSON string with wind, temp, humidity).
  final String? conditions;

  // ─── Result ────────────────────────────────────────────────────────────

  /// Primary outcome of the shot.
  final ShotResult? result;

  /// Whether this shot incurred a penalty stroke.
  final bool isPenalty;

  /// Whether this was a provisional ball.
  final bool isProvisional;

  /// Whether this shot was declared a mulligan.
  final bool isMulligan;

  /// If non-null, this shot was merged into the referenced shot.
  final String? mergedIntoShotId;

  // ─── Source / Quality ───────────────────────────────────────────────────

  /// How the shot was created.
  final ShotSource source;

  /// Confidence in shot detection quality (0.0–1.0). Null for manual shots.
  final double? confidence;

  // ─── Sync Metadata ─────────────────────────────────────────────────────

  /// Local-first sync status for this shot.
  final SyncStatus syncStatus;

  /// Client-generated UUID v4 idempotency key for this mutation.
  final String idempotencyKey;

  /// Server-side sync status from API response.
  final SyncStatus serverSyncStatus;

  // ─── Audit ─────────────────────────────────────────────────────────────

  /// When this shot was created locally.
  final DateTime createdAt;

  /// When this shot was last modified locally.
  final DateTime updatedAt;

  const Shot({
    required this.id,
    required this.roundId,
    required this.flightId,
    required this.playerId,
    required this.holeNumber,
    required this.shotNumber,
    this.clubId,
    required this.startedAt,
    this.endedAt,
    this.startLocation,
    this.endLocation,
    this.lie,
    this.distanceYards,
    this.distanceMeters,
    this.conditions,
    this.result,
    this.isPenalty = false,
    this.isProvisional = false,
    this.isMulligan = false,
    this.mergedIntoShotId,
    this.source = ShotSource.manual,
    this.confidence,
    this.syncStatus = SyncStatus.pending,
    this.idempotencyKey = '',
    this.serverSyncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  // ─── Derived State ──────────────────────────────────────────────────────

  /// True if the shot has been ended (GPS lock acquired at rest).
  bool get isEnded => endedAt != null;

  /// True if the shot is active (started but not yet ended).
  bool get isActive => !isEnded;

  /// True if this shot was merged into another shot.
  bool get isMerged => mergedIntoShotId != null;

  // ─── Copy ──────────────────────────────────────────────────────────────

  Shot copyWith({
    String? id,
    String? roundId,
    String? flightId,
    String? playerId,
    int? holeNumber,
    int? shotNumber,
    String? clubId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? startLocation,
    String? endLocation,
    ShotLie? lie,
    double? distanceYards,
    double? distanceMeters,
    String? conditions,
    ShotResult? result,
    bool? isPenalty,
    bool? isProvisional,
    bool? isMulligan,
    String? mergedIntoShotId,
    ShotSource? source,
    double? confidence,
    SyncStatus? syncStatus,
    String? idempotencyKey,
    SyncStatus? serverSyncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearClubId = false,
    bool clearEndedAt = false,
    bool clearStartLocation = false,
    bool clearEndLocation = false,
    bool clearLie = false,
    bool clearDistanceYards = false,
    bool clearDistanceMeters = false,
    bool clearConditions = false,
    bool clearResult = false,
    bool clearMergedIntoShotId = false,
    bool clearConfidence = false,
  }) {
    return Shot(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      flightId: flightId ?? this.flightId,
      playerId: playerId ?? this.playerId,
      holeNumber: holeNumber ?? this.holeNumber,
      shotNumber: shotNumber ?? this.shotNumber,
      clubId: clearClubId ? null : (clubId ?? this.clubId),
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      startLocation: clearStartLocation
          ? null
          : (startLocation ?? this.startLocation),
      endLocation: clearEndLocation ? null : (endLocation ?? this.endLocation),
      lie: clearLie ? null : (lie ?? this.lie),
      distanceYards: clearDistanceYards
          ? null
          : (distanceYards ?? this.distanceYards),
      distanceMeters: clearDistanceMeters
          ? null
          : (distanceMeters ?? this.distanceMeters),
      conditions: clearConditions ? null : (conditions ?? this.conditions),
      result: clearResult ? null : (result ?? this.result),
      isPenalty: isPenalty ?? this.isPenalty,
      isProvisional: isProvisional ?? this.isProvisional,
      isMulligan: isMulligan ?? this.isMulligan,
      mergedIntoShotId: clearMergedIntoShotId
          ? null
          : (mergedIntoShotId ?? this.mergedIntoShotId),
      source: source ?? this.source,
      confidence: clearConfidence ? null : (confidence ?? this.confidence),
      syncStatus: syncStatus ?? this.syncStatus,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      serverSyncStatus: serverSyncStatus ?? this.serverSyncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── Serialization ─────────────────────────────────────────────────────

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'round_id': roundId,
      'flight_id': flightId,
      'player_id': playerId,
      'hole_number': holeNumber,
      'shot_number': shotNumber,
      'club_id': clubId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'start_location': startLocation,
      'end_location': endLocation,
      'lie': lie?.toApiValue(),
      'distance_yards': distanceYards,
      'distance_meters': distanceMeters,
      'conditions': conditions,
      'result': result?.toApiValue(),
      'is_penalty': isPenalty ? 1 : 0,
      'is_provisional': isProvisional ? 1 : 0,
      'is_mulligan': isMulligan ? 1 : 0,
      'merged_into_shot_id': mergedIntoShotId,
      'source': source.name,
      'confidence': confidence,
      'sync_status': syncStatus.name,
      'idempotency_key': idempotencyKey,
      'server_sync_status': serverSyncStatus.name,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Reconstruct from a SQLite row.
  factory Shot.fromMap(Map<String, dynamic> map) {
    return Shot(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      flightId: map['flight_id'] as String,
      playerId: map['player_id'] as String,
      holeNumber: (map['hole_number'] as num).toInt(),
      shotNumber: (map['shot_number'] as num).toInt(),
      clubId: map['club_id'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      startLocation: map['start_location'] as String?,
      endLocation: map['end_location'] as String?,
      lie: ShotLie.fromString(map['lie'] as String?),
      distanceYards: (map['distance_yards'] as num?)?.toDouble(),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      conditions: map['conditions'] as String?,
      result: ShotResult.fromString(map['result'] as String?),
      isPenalty: ((map['is_penalty'] as num?)?.toInt()) == 1,
      isProvisional: ((map['is_provisional'] as num?)?.toInt()) == 1,
      isMulligan: ((map['is_mulligan'] as num?)?.toInt()) == 1,
      mergedIntoShotId: map['merged_into_shot_id'] as String?,
      source: ShotSource.fromString(map['source'] as String?),
      confidence: (map['confidence'] as num?)?.toDouble(),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == (map['sync_status'] as String? ?? 'pending'),
        orElse: () => SyncStatus.pending,
      ),
      idempotencyKey: map['idempotency_key'] as String? ?? '',
      serverSyncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == (map['server_sync_status'] as String? ?? 'pending'),
        orElse: () => SyncStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Parse from API JSON (OpenAPI DTO format).
  factory Shot.fromJson(Map<String, dynamic> json) {
    return Shot(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      flightId: json['flightId'] as String,
      playerId: json['playerId'] as String,
      holeNumber: (json['holeNumber'] as num).toInt(),
      shotNumber: (json['shotNumber'] as num).toInt(),
      clubId: json['clubId'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      startLocation: json['startLocation'] as String?,
      endLocation: json['endLocation'] as String?,
      lie: ShotLie.fromString(json['lie'] as String?),
      distanceYards: (json['distanceYards'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      conditions: json['conditions'] as String?,
      result: ShotResult.fromString(json['result'] as String?),
      isPenalty: json['isPenalty'] as bool? ?? false,
      isProvisional: json['isProvisional'] as bool? ?? false,
      isMulligan: json['isMulligan'] as bool? ?? false,
      mergedIntoShotId: json['mergedIntoShotId'] as String?,
      source: ShotSource.fromString(json['source'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble(),
      syncStatus: SyncStatus.synced, // API confirms synced
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      serverSyncStatus: SyncStatus.synced,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roundId': roundId,
    'flightId': flightId,
    'playerId': playerId,
    'holeNumber': holeNumber,
    'shotNumber': shotNumber,
    'clubId': clubId,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'startLocation': startLocation,
    'endLocation': endLocation,
    'lie': lie?.toApiValue(),
    'distanceYards': distanceYards,
    'distanceMeters': distanceMeters,
    'conditions': conditions,
    'result': result?.toApiValue(),
    'isPenalty': isPenalty,
    'isProvisional': isProvisional,
    'isMulligan': isMulligan,
    'mergedIntoShotId': mergedIntoShotId,
    'source': source.name,
    'confidence': confidence,
    'syncStatus': syncStatus.name,
    'idempotencyKey': idempotencyKey,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    roundId,
    flightId,
    playerId,
    holeNumber,
    shotNumber,
    clubId,
    startedAt,
    endedAt,
    startLocation,
    endLocation,
    lie,
    distanceYards,
    distanceMeters,
    conditions,
    result,
    isPenalty,
    isProvisional,
    isMulligan,
    mergedIntoShotId,
    source,
    confidence,
    syncStatus,
    idempotencyKey,
    serverSyncStatus,
    createdAt,
    updatedAt,
  ];
}
