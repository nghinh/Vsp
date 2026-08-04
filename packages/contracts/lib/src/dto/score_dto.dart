// ScoreDto — VSP Contracts Package
//
// API serialization model for Score entity.
// Mirrors Score domain model in apps/mobile/lib/domain/models/score.dart.
//
// Story 5.3 — Slice 1: Domain Models & Contracts

/// Score sync status enum — mirrors ScoreSyncStatus in mobile domain model.
enum ScoreSyncStatusDto {
  local,
  pending,
  synced,
  conflict;

  static ScoreSyncStatusDto fromString(String value) {
    return ScoreSyncStatusDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ScoreSyncStatusDto.local,
    );
  }
}

/// Score DTO for API request/response serialization.
class ScoreDto {
  final String id;
  final String flightId;
  final String holeId;
  final String playerId;
  final int? grossScore;
  final int? putts;
  final int? penalties;
  final bool? fairwayHit;
  final bool? gir;
  final bool? bunker;
  final String? notes;
  final DateTime? enteredAt;
  final ScoreSyncStatusDto syncStatus;
  final int version;
  final DateTime updatedAt;

  const ScoreDto({
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
    this.syncStatus = ScoreSyncStatusDto.local,
    this.version = 1,
    required this.updatedAt,
  });

  /// Parse from API response JSON.
  factory ScoreDto.fromJson(Map<String, dynamic> json) {
    return ScoreDto(
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
      syncStatus: ScoreSyncStatusDto.fromString(
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
}
