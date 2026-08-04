// WatchRoundSession — VSP Domain Package
//
// Watch-specific round session model.
// Captures the minimal state needed by the watch app for an active round.
//
// Story 10.1 — Slice 1: Watch Adapter & Data Contracts

import 'package:equatable/equatable.dart';

/// Watch round session status.
enum WatchRoundStatus {
  /// Round is actively in progress on the watch.
  active,

  /// Round has been paused (e.g., golfer stopped mid-hole).
  paused,

  /// Round completed and synced.
  completed,

  /// Round was abandoned.
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

/// Per-player hole score entry for watch sync.
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

  Map<String, dynamic> toMap() => {
        'player_id': playerId,
        'hole_number': holeNumber,
        'strokes': strokes,
        'putts': putts,
        'penalties': penalties,
        'fairway_hit': fairwayHit == true ? 1 : 0,
        'gir': gir == true ? 1 : 0,
        'entered_at': enteredAt?.toUtc().toIso8601String(),
      };

  factory WatchHoleScore.fromMap(Map<String, dynamic> map) => WatchHoleScore(
        playerId: map['player_id'] as String,
        holeNumber: map['hole_number'] as int,
        strokes: map['strokes'] as int?,
        putts: map['putts'] as int?,
        penalties: map['penalties'] as int?,
        fairwayHit: (map['fairway_hit'] as int?) == 1,
        gir: (map['gir'] as int?) == 1,
        enteredAt: map['entered_at'] != null
            ? DateTime.parse(map['entered_at'] as String)
            : null,
      );

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
///
/// This is the watch-side counterpart to the mobile Round model.
/// It captures only the data the watch needs for distance display,
/// score entry, and navigation without requiring full course geometry.
class WatchRoundSession extends Equatable {
  /// Local UUID for this watch round.
  final String id;

  /// Reference to the originating round ID on mobile/backend (null if not yet synced).
  final String? roundId;

  /// Course ID this round is for.
  final int courseId;

  /// Course name (denormalized for watch display).
  final String courseName;

  /// Tee set ID used at round start.
  final String teeSetId;

  /// Current hole number (1–18, or 19+ for overflow).
  final int currentHole;

  /// Par for the current hole.
  final int currentPar;

  /// Total holes in this round (default 18).
  final int totalHoles;

  /// Watch round status.
  final WatchRoundStatus status;

  /// Current GPS quality estimate.
  final WatchGpsQuality gpsQuality;

  /// Estimated horizontal GPS accuracy in meters.
  final double gpsAccuracyMeters;

  /// Whether the watch has a live GPS fix.
  final bool hasGpsFix;

  /// Per-player scores for each hole.
  final List<WatchHoleScore> scores;

  /// When the round was started on the watch.
  final DateTime startedAt;

  /// When the round was last updated.
  final DateTime updatedAt;

  /// When the round ended (null if still active).
  final DateTime? endedAt;

  /// Package version used for this round.
  final String packageVersion;

  /// Sync status: local-only, pending sync, or synced.
  final String syncStatus; // 'local', 'pending', 'synced'

  const WatchRoundSession({
    required this.id,
    this.roundId,
    required this.courseId,
    required this.courseName,
    required this.teeSetId,
    required this.currentHole,
    required this.currentPar,
    this.totalHoles = 18,
    required this.status,
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

  /// True if this session is currently active.
  bool get isActive => status == WatchRoundStatus.active;

  /// Total strokes for a given player across all scored holes.
  int totalStrokesFor(String playerId) {
    return scores
        .where((s) => s.playerId == playerId && s.strokes != null)
        .fold(0, (sum, s) => sum + s.strokes!);
  }

  /// Total relative score (strokes - par) for a given player.
  int relativeScoreFor(String playerId, int totalPar) {
    return totalStrokesFor(playerId) - totalPar;
  }

  /// Copy with updated fields.
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

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'round_id': roundId,
      'course_id': courseId,
      'course_name': courseName,
      'tee_set_id': teeSetId,
      'current_hole': currentHole,
      'current_par': currentPar,
      'total_holes': totalHoles,
      'status': status.name,
      'gps_quality': gpsQuality.name,
      'gps_accuracy_meters': gpsAccuracyMeters,
      'has_gps_fix': hasGpsFix ? 1 : 0,
      'scores_json': _encodeScores(scores),
      'started_at': startedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'package_version': packageVersion,
      'sync_status': syncStatus,
    };
  }

  /// Reconstruct from a SQLite row.
  factory WatchRoundSession.fromMap(Map<String, dynamic> map) {
    return WatchRoundSession(
      id: map['id'] as String,
      roundId: map['round_id'] as String?,
      courseId: map['course_id'] as int,
      courseName: map['course_name'] as String,
      teeSetId: map['tee_set_id'] as String,
      currentHole: map['current_hole'] as int,
      currentPar: map['current_par'] as int,
      totalHoles: map['total_holes'] as int? ?? 18,
      status: WatchRoundStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => WatchRoundStatus.active,
      ),
      gpsQuality: WatchGpsQuality.values.firstWhere(
        (e) => e.name == map['gps_quality'],
        orElse: () => WatchGpsQuality.unknown,
      ),
      gpsAccuracyMeters: (map['gps_accuracy_meters'] as num?)?.toDouble() ?? 0,
      hasGpsFix: (map['has_gps_fix'] as int?) == 1,
      scores: _decodeScores(map['scores_json'] as String?),
      startedAt: DateTime.parse(map['started_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      packageVersion: map['package_version'] as String,
      syncStatus: map['sync_status'] as String? ?? 'local',
    );
  }

  static String _encodeScores(List<WatchHoleScore> scores) {
    // Simple JSON encoding for scores list
    final list = scores.map((s) => s.toMap()).toList();
    return _jsonEncode(list);
  }

  static List<WatchHoleScore> _decodeScores(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = _jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => WatchHoleScore.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _jsonEncode(List<Map<String, dynamic>> list) {
    final buf = StringBuffer('[');
    for (var i = 0; i < list.length; i++) {
      if (i > 0) buf.write(',');
      buf.write(_mapToJson(list[i]));
    }
    buf.write(']');
    return buf.toString();
  }

  static String _mapToJson(Map<String, dynamic> map) {
    final entries = map.entries.map((e) {
      final v = e.value;
      if (v == null) return '"${e.key}":null';
      if (v is String) return '"${e.key}":"${v.replaceAll('"', '\\"')}"';
      if (v is num || v is bool) return '"${e.key}":$v';
      return '"${e.key}":"${v.toString()}"';
    }).join(',');
    return '{$entries}';
  }

  static dynamic _jsonDecode(String json) {
    // Minimal JSON parser for scores — handles the simple structures we write
    if (json.startsWith('[')) {
      final list = <dynamic>[];
      final inner = json.substring(1, json.length - 1).trim();
      if (inner.isEmpty) return list;
      // Simple split — adequate for our flat score objects
      var depth = 0;
      var start = 0;
      for (var i = 0; i < inner.length; i++) {
        if (inner[i] == '{') depth++;
        if (inner[i] == '}') depth--;
        if (inner[i] == ',' && depth == 0) {
          list.add(_jsonDecode(inner.substring(start, i)));
          start = i + 1;
        }
      }
      list.add(_jsonDecode(inner.substring(start)));
      return list;
    } else if (json.startsWith('{')) {
      final map = <String, dynamic>{};
      final inner = json.substring(1, json.length - 1).trim();
      if (inner.isEmpty) return map;
      var depth = 0;
      var start = 0;
      var inString = false;
      for (var i = 0; i < inner.length; i++) {
        final c = inner[i];
        if (c == '"' && (i == 0 || inner[i - 1] != '\\')) inString = !inString;
        if (!inString) {
          if (c == '{') depth++;
          if (c == '}') depth--;
          if (c == ',' && depth == 0) {
            final entry = inner.substring(start, i);
            final colonIdx = entry.indexOf(':');
            if (colonIdx > 0) {
              final k = entry.substring(0, colonIdx).trim();
              final v = entry.substring(colonIdx + 1).trim();
              map[_unquote(k)] = _parseValue(v);
            }
            start = i + 1;
          }
        }
      }
      final lastEntry = inner.substring(start).trim();
      final colonIdx = lastEntry.indexOf(':');
      if (colonIdx > 0) {
        final k = lastEntry.substring(0, colonIdx).trim();
        final v = lastEntry.substring(colonIdx + 1).trim();
        map[_unquote(k)] = _parseValue(v);
      }
      return map;
    }
    return json;
  }

  static String _unquote(String s) {
    if (s.startsWith('"') && s.endsWith('"')) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  static dynamic _parseValue(String v) {
    if (v == 'null') return null;
    if (v == 'true') return true;
    if (v == 'false') return false;
    if (v.startsWith('"') && v.endsWith('"')) return _unquote(v);
    final n = num.tryParse(v);
    if (n != null) return n;
    return v;
  }

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
