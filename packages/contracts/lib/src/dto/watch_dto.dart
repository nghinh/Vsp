// Watch DTOs — VSP Contracts Package
//
// API serialization models for Apple Watch round data.
// Used by the watch adapter layer to sync data with the mobile/backend.
//
// Story 10.1 — Slice 1: Watch Adapter & Data Contracts

// ─── Distance Data DTO ─────────────────────────────────────────────────────────

/// Distance value with confidence — serializable form.
class WatchDistanceDto {
  final double meters;
  final double confidence;

  const WatchDistanceDto({
    required this.meters,
    required this.confidence,
  });

  factory WatchDistanceDto.fromJson(Map<String, dynamic> json) => WatchDistanceDto(
        meters: (json['meters'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'meters': meters,
        'confidence': confidence,
      };
}

/// Hazard distance entry for API serialization.
class WatchHazardDistanceDto {
  final String type;
  final String label;
  final double meters;
  final double confidence;
  final double? carryMeters;

  const WatchHazardDistanceDto({
    required this.type,
    required this.label,
    required this.meters,
    required this.confidence,
    this.carryMeters,
  });

  factory WatchHazardDistanceDto.fromJson(Map<String, dynamic> json) =>
      WatchHazardDistanceDto(
        type: json['type'] as String,
        label: json['label'] as String,
        meters: (json['meters'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        carryMeters: (json['carryMeters'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'meters': meters,
        'confidence': confidence,
        if (carryMeters != null) 'carryMeters': carryMeters,
      };
}

/// Distance data DTO for API serialization.
class WatchDistanceDataDto {
  final int holeNumber;
  final int par;
  final WatchDistanceDto frontGreen;
  final WatchDistanceDto centerGreen;
  final WatchDistanceDto backGreen;
  final WatchDistanceDto? pin;
  final List<WatchHazardDistanceDto> hazards;
  final double confidence;
  final double gpsAccuracyMeters;
  final bool isLive;
  final DateTime computedAt;
  final int? holeLengthMeters;

  const WatchDistanceDataDto({
    required this.holeNumber,
    required this.par,
    required this.frontGreen,
    required this.centerGreen,
    required this.backGreen,
    this.pin,
    this.hazards = const [],
    required this.confidence,
    required this.gpsAccuracyMeters,
    this.isLive = true,
    required this.computedAt,
    this.holeLengthMeters,
  });

  factory WatchDistanceDataDto.fromJson(Map<String, dynamic> json) =>
      WatchDistanceDataDto(
        holeNumber: json['holeNumber'] as int,
        par: json['par'] as int,
        frontGreen: WatchDistanceDto.fromJson(
            json['frontGreen'] as Map<String, dynamic>),
        centerGreen: WatchDistanceDto.fromJson(
            json['centerGreen'] as Map<String, dynamic>),
        backGreen: WatchDistanceDto.fromJson(
            json['backGreen'] as Map<String, dynamic>),
        pin: json['pin'] != null
            ? WatchDistanceDto.fromJson(json['pin'] as Map<String, dynamic>)
            : null,
        hazards: (json['hazards'] as List<dynamic>?)
                ?.map((e) =>
                    WatchHazardDistanceDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        confidence: (json['confidence'] as num).toDouble(),
        gpsAccuracyMeters: (json['gpsAccuracyMeters'] as num).toDouble(),
        isLive: json['isLive'] as bool? ?? true,
        computedAt: DateTime.parse(json['computedAt'] as String),
        holeLengthMeters: json['holeLengthMeters'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'holeNumber': holeNumber,
        'par': par,
        'frontGreen': frontGreen.toJson(),
        'centerGreen': centerGreen.toJson(),
        'backGreen': backGreen.toJson(),
        if (pin != null) 'pin': pin!.toJson(),
        'hazards': hazards.map((h) => h.toJson()).toList(),
        'confidence': confidence,
        'gpsAccuracyMeters': gpsAccuracyMeters,
        'isLive': isLive,
        'computedAt': computedAt.toIso8601String(),
        if (holeLengthMeters != null) 'holeLengthMeters': holeLengthMeters,
      };
}

// ─── Score Entry DTO ───────────────────────────────────────────────────────────

/// Score sync status for watch score entries.
enum WatchScoreSyncStatusDto {
  local,
  pending,
  synced,
  conflict;

  static WatchScoreSyncStatusDto fromString(String value) {
    return WatchScoreSyncStatusDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => WatchScoreSyncStatusDto.local,
    );
  }
}

/// Watch score entry DTO for API serialization.
class WatchScoreEntryDto {
  final String id;
  final String? roundId; // null until synced
  final String playerId;
  final int holeNumber;
  final int? grossScore;
  final int? putts;
  final int? penalties;
  final bool? fairwayHit;
  final bool? gir;
  final String? notes;
  final DateTime enteredAt;
  final WatchScoreSyncStatusDto syncStatus;
  final int version;
  final DateTime updatedAt;

  const WatchScoreEntryDto({
    required this.id,
    this.roundId,
    required this.playerId,
    required this.holeNumber,
    this.grossScore,
    this.putts,
    this.penalties,
    this.fairwayHit,
    this.gir,
    this.notes,
    required this.enteredAt,
    this.syncStatus = WatchScoreSyncStatusDto.local,
    this.version = 1,
    required this.updatedAt,
  });

  factory WatchScoreEntryDto.fromJson(Map<String, dynamic> json) =>
      WatchScoreEntryDto(
        id: json['id'] as String,
        roundId: json['roundId'] as String?,
        playerId: json['playerId'] as String,
        holeNumber: json['holeNumber'] as int,
        grossScore: json['grossScore'] as int?,
        putts: json['putts'] as int?,
        penalties: json['penalties'] as int?,
        fairwayHit: json['fairwayHit'] as bool?,
        gir: json['gir'] as bool?,
        notes: json['notes'] as String?,
        enteredAt: DateTime.parse(json['enteredAt'] as String),
        syncStatus: WatchScoreSyncStatusDto.fromString(
          json['syncStatus'] as String? ?? 'local',
        ),
        version: json['version'] as int? ?? 1,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (roundId != null) 'roundId': roundId,
        'playerId': playerId,
        'holeNumber': holeNumber,
        'grossScore': grossScore,
        'putts': putts,
        'penalties': penalties,
        'fairwayHit': fairwayHit,
        'gir': gir,
        'notes': notes,
        'enteredAt': enteredAt.toIso8601String(),
        'syncStatus': syncStatus.name,
        'version': version,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

// ─── Round Session DTO ────────────────────────────────────────────────────────

/// Watch round session DTO for API sync.
class WatchRoundSessionDto {
  final String id;
  final String? roundId;
  final int courseId;
  final String courseName;
  final String teeSetId;
  final int currentHole;
  final int currentPar;
  final int totalHoles;
  final String status; // 'active', 'paused', 'completed', 'abandoned'
  final String gpsQuality; // 'unknown', 'poor', 'moderate', 'good', 'excellent'
  final double gpsAccuracyMeters;
  final bool hasGpsFix;
  final List<WatchHoleScoreDto> scores;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? endedAt;
  final String packageVersion;
  final String syncStatus;

  const WatchRoundSessionDto({
    required this.id,
    this.roundId,
    required this.courseId,
    required this.courseName,
    required this.teeSetId,
    required this.currentHole,
    required this.currentPar,
    this.totalHoles = 18,
    required this.status,
    this.gpsQuality = 'unknown',
    this.gpsAccuracyMeters = 0,
    this.hasGpsFix = false,
    this.scores = const [],
    required this.startedAt,
    required this.updatedAt,
    this.endedAt,
    required this.packageVersion,
    this.syncStatus = 'local',
  });

  factory WatchRoundSessionDto.fromJson(Map<String, dynamic> json) =>
      WatchRoundSessionDto(
        id: json['id'] as String,
        roundId: json['roundId'] as String?,
        courseId: json['courseId'] as int,
        courseName: json['courseName'] as String,
        teeSetId: json['teeSetId'] as String,
        currentHole: json['currentHole'] as int,
        currentPar: json['currentPar'] as int,
        totalHoles: json['totalHoles'] as int? ?? 18,
        status: json['status'] as String? ?? 'active',
        gpsQuality: json['gpsQuality'] as String? ?? 'unknown',
        gpsAccuracyMeters:
            (json['gpsAccuracyMeters'] as num?)?.toDouble() ?? 0,
        hasGpsFix: json['hasGpsFix'] as bool? ?? false,
        scores: (json['scores'] as List<dynamic>?)
                ?.map((e) =>
                    WatchHoleScoreDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        startedAt: DateTime.parse(json['startedAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        endedAt: json['endedAt'] != null
            ? DateTime.parse(json['endedAt'] as String)
            : null,
        packageVersion: json['packageVersion'] as String,
        syncStatus: json['syncStatus'] as String? ?? 'local',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (roundId != null) 'roundId': roundId,
        'courseId': courseId,
        'courseName': courseName,
        'teeSetId': teeSetId,
        'currentHole': currentHole,
        'currentPar': currentPar,
        'totalHoles': totalHoles,
        'status': status,
        'gpsQuality': gpsQuality,
        'gpsAccuracyMeters': gpsAccuracyMeters,
        'hasGpsFix': hasGpsFix,
        'scores': scores.map((s) => s.toJson()).toList(),
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        'packageVersion': packageVersion,
        'syncStatus': syncStatus,
      };
}

/// Per-hole score DTO for round sync.
class WatchHoleScoreDto {
  final String playerId;
  final int holeNumber;
  final int? strokes;
  final int? putts;
  final int? penalties;
  final bool? fairwayHit;
  final bool? gir;
  final DateTime? enteredAt;

  const WatchHoleScoreDto({
    required this.playerId,
    required this.holeNumber,
    this.strokes,
    this.putts,
    this.penalties,
    this.fairwayHit,
    this.gir,
    this.enteredAt,
  });

  factory WatchHoleScoreDto.fromJson(Map<String, dynamic> json) =>
      WatchHoleScoreDto(
        playerId: json['playerId'] as String,
        holeNumber: json['holeNumber'] as int,
        strokes: json['strokes'] as int?,
        putts: json['putts'] as int?,
        penalties: json['penalties'] as int?,
        fairwayHit: json['fairwayHit'] as bool?,
        gir: json['gir'] as bool?,
        enteredAt: json['enteredAt'] != null
            ? DateTime.parse(json['enteredAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'holeNumber': holeNumber,
        'strokes': strokes,
        'putts': putts,
        'penalties': penalties,
        'fairwayHit': fairwayHit,
        'gir': gir,
        if (enteredAt != null) 'enteredAt': enteredAt!.toIso8601String(),
      };
}
