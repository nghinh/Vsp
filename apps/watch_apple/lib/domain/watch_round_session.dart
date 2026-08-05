// Watch Round Session — VSP Watch Apple App (Local Domain)
//
// Watch-specific round session model.
// Captures the minimal state needed by the watch app for an active round.
//
// Story 10.1 — Slice 2/3: Watch UI Shell & Navigation / Quick Score Entry

import 'package:equatable/equatable.dart';

/// Watch round session status.
enum WatchRoundStatus {
  active,
  paused,
  completed,
  abandoned,
}

/// GPS fix quality for watch display.
enum WatchGpsQuality {
  unknown,
  poor,    // >= 20m accuracy
  moderate, // 10–20m accuracy
  good,    // 5–10m accuracy
  excellent, // < 5m accuracy
}

/// Per-player hole score entry.
class WatchHoleScore extends Equatable {
  final String playerId;
  final int holeNumber;
  final int? strokes;
  final int? putts;
  final int? penalties;
  final bool? fairwayHit;
  final bool? gir;
  final DateTime? enteredAt;

  const WatchHoleScore({
    required this.playerId,
    required this.holeNumber,
    this.strokes,
    this.putts,
    this.penalties,
    this.fairwayHit,
    this.gir,
    this.enteredAt,
  });

  WatchHoleScore copyWith({
    String? playerId,
    int? holeNumber,
    int? strokes,
    int? putts,
    int? penalties,
    bool? fairwayHit,
    bool? gir,
    DateTime? enteredAt,
  }) =>
      WatchHoleScore(
        playerId: playerId ?? this.playerId,
        holeNumber: holeNumber ?? this.holeNumber,
        strokes: strokes ?? this.strokes,
        putts: putts ?? this.putts,
        penalties: penalties ?? this.penalties,
        fairwayHit: fairwayHit ?? this.fairwayHit,
        gir: gir ?? this.gir,
        enteredAt: enteredAt ?? this.enteredAt,
      );

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'holeNumber': holeNumber,
        'strokes': strokes,
        'putts': putts,
        'penalties': penalties,
        'fairwayHit': fairwayHit,
        'gir': gir,
        'enteredAt': enteredAt?.toIso8601String(),
      };

  factory WatchHoleScore.fromMap(Map<String, dynamic> map) => WatchHoleScore(
        playerId: map['playerId'] as String,
        holeNumber: map['holeNumber'] as int,
        strokes: map['strokes'] as int?,
        putts: map['putts'] as int?,
        penalties: map['penalties'] as int?,
        fairwayHit: map['fairwayHit'] as bool?,
        gir: map['gir'] as bool?,
        enteredAt: map['enteredAt'] != null
            ? DateTime.parse(map['enteredAt'] as String)
            : null,
      );

  @override
  List<Object?> get props => [
        playerId,
        holeNumber,
        strokes,
        putts,
        penalties,
        fairwayHit,
        gir,
        enteredAt,
      ];
}

/// Watch round session — represents an active or recent round on the watch.
class WatchRoundSession extends Equatable {
  final String id;
  final String? roundId;
  final int courseId;
  final String courseName;
  final String teeSetId;
  final int currentHole;
  final int currentPar;
  final int totalHoles;
  final WatchRoundStatus status;
  final WatchGpsQuality gpsQuality;
  final double gpsAccuracyMeters;
  final bool hasGpsFix;
  final List<WatchHoleScore> scores;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? endedAt;
  final String packageVersion;
  final String syncStatus;

  const WatchRoundSession({
    required this.id,
    this.roundId,
    required this.courseId,
    required this.courseName,
    required this.teeSetId,
    required this.currentHole,
    required this.currentPar,
    this.totalHoles = 18,
    this.status = WatchRoundStatus.active,
    this.gpsQuality = WatchGpsQuality.unknown,
    this.gpsAccuracyMeters = 0,
    this.hasGpsFix = false,
    this.scores = const [],
    required this.startedAt,
    required this.updatedAt,
    this.endedAt,
    required this.packageVersion,
    this.syncStatus = 'local',
  });

  bool get isActive => status == WatchRoundStatus.active;

  int totalStrokesFor(String playerId) {
    return scores
        .where((s) => s.playerId == playerId && s.strokes != null)
        .fold(0, (sum, s) => sum + s.strokes!);
  }

  int relativeScoreFor(String playerId, int totalPar) {
    return totalStrokesFor(playerId) - totalPar;
  }

  WatchRoundSession copyWith({
    String? id,
    String? roundId,
    int? courseId,
    String? courseName,
    String? teeSetId,
    int? currentHole,
    int? currentPar,
    int? totalHoles,
    WatchRoundStatus? status,
    WatchGpsQuality? gpsQuality,
    double? gpsAccuracyMeters,
    bool? hasGpsFix,
    List<WatchHoleScore>? scores,
    DateTime? startedAt,
    DateTime? updatedAt,
    DateTime? endedAt,
    String? packageVersion,
    String? syncStatus,
  }) {
    return WatchRoundSession(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      teeSetId: teeSetId ?? this.teeSetId,
      currentHole: currentHole ?? this.currentHole,
      currentPar: currentPar ?? this.currentPar,
      totalHoles: totalHoles ?? this.totalHoles,
      status: status ?? this.status,
      gpsQuality: gpsQuality ?? this.gpsQuality,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      hasGpsFix: hasGpsFix ?? this.hasGpsFix,
      scores: scores ?? this.scores,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      endedAt: endedAt ?? this.endedAt,
      packageVersion: packageVersion ?? this.packageVersion,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Serialize to a persistence-friendly map (used for local durability and
  /// restart recovery).
  Map<String, dynamic> toMap() => {
        'id': id,
        'roundId': roundId,
        'courseId': courseId,
        'courseName': courseName,
        'teeSetId': teeSetId,
        'currentHole': currentHole,
        'currentPar': currentPar,
        'totalHoles': totalHoles,
        'status': status.name,
        'gpsQuality': gpsQuality.name,
        'gpsAccuracyMeters': gpsAccuracyMeters,
        'hasGpsFix': hasGpsFix,
        'scores': scores.map((s) => s.toMap()).toList(),
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'packageVersion': packageVersion,
        'syncStatus': syncStatus,
      };

  /// Restore from a persisted map. Tolerant of unknown enum values.
  factory WatchRoundSession.fromMap(Map<String, dynamic> map) =>
      WatchRoundSession(
        id: map['id'] as String,
        roundId: map['roundId'] as String?,
        courseId: map['courseId'] as int,
        courseName: map['courseName'] as String,
        teeSetId: map['teeSetId'] as String,
        currentHole: map['currentHole'] as int,
        currentPar: map['currentPar'] as int,
        totalHoles: map['totalHoles'] as int? ?? 18,
        status: WatchRoundStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => WatchRoundStatus.active,
        ),
        gpsQuality: WatchGpsQuality.values.firstWhere(
          (e) => e.name == map['gpsQuality'],
          orElse: () => WatchGpsQuality.unknown,
        ),
        gpsAccuracyMeters: (map['gpsAccuracyMeters'] as num?)?.toDouble() ?? 0,
        hasGpsFix: map['hasGpsFix'] as bool? ?? false,
        scores: (map['scores'] as List<dynamic>?)
                ?.map((e) => WatchHoleScore.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        startedAt: DateTime.parse(map['startedAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        endedAt: map['endedAt'] != null
            ? DateTime.parse(map['endedAt'] as String)
            : null,
        packageVersion: map['packageVersion'] as String,
        syncStatus: map['syncStatus'] as String? ?? 'local',
      );

  @override
  List<Object?> get props => [
        id,
        roundId,
        courseId,
        courseName,
        teeSetId,
        currentHole,
        currentPar,
        totalHoles,
        status,
        gpsQuality,
        gpsAccuracyMeters,
        hasGpsFix,
        scores,
        startedAt,
        updatedAt,
        endedAt,
        packageVersion,
        syncStatus,
      ];
}

/// Score entry for a specific hole.
class WatchScoreEntry extends Equatable {
  final String id;
  final String? roundId;
  final String playerId;
  final int holeNumber;
  final int? grossScore;
  final int? putts;
  final int? penalties;
  final bool? fairwayHit;
  final bool? gir;
  final String? notes;
  final DateTime enteredAt;
  final String syncStatus;
  final int version;

  const WatchScoreEntry({
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
    this.syncStatus = 'local',
    this.version = 1,
  });

  WatchScoreEntry copyWith({
    String? id,
    String? roundId,
    String? playerId,
    int? holeNumber,
    int? grossScore,
    int? putts,
    int? penalties,
    bool? fairwayHit,
    bool? gir,
    String? notes,
    DateTime? enteredAt,
    String? syncStatus,
    int? version,
  }) {
    return WatchScoreEntry(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      playerId: playerId ?? this.playerId,
      holeNumber: holeNumber ?? this.holeNumber,
      grossScore: grossScore ?? this.grossScore,
      putts: putts ?? this.putts,
      penalties: penalties ?? this.penalties,
      fairwayHit: fairwayHit ?? this.fairwayHit,
      gir: gir ?? this.gir,
      notes: notes ?? this.notes,
      enteredAt: enteredAt ?? this.enteredAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roundId,
        playerId,
        holeNumber,
        grossScore,
        putts,
        penalties,
        fairwayHit,
        gir,
        notes,
        enteredAt,
        syncStatus,
        version,
      ];
}
