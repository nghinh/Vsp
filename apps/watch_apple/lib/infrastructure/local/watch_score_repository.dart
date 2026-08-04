// Watch Score Repository — VSP Watch Apple App
//
// Local persistence and sync queue for watch score entries.
// Implements AC-5, AC-6: quick score entry with local-first persistence
// and idempotent sync queue.
//
// Story 10.1 — Slice 3: Quick Score Entry

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../domain/watch_round_session.dart';

/// Repository for watch score persistence and sync queue.
///
/// Uses SharedPreferences for simple key-value storage on watch.
/// In a production app, this would use watch-specific SQLite
/// but SharedPreferences is sufficient for MVP.
///
/// Sync strategy:
/// 1. All scores saved locally first (durable write)
/// 2. Scores queued for sync with 'local' status
/// 3. When connectivity available, sync to phone → backend
/// 4. On success, update status to 'synced'
/// 5. Idempotent: re-sync same score has no duplicate effect
class WatchScoreRepository {
  static const String _scoresKey = 'watch_scores';
  static const String _pendingSyncKey = 'watch_pending_sync';
  static const String _sessionKey = 'watch_session';

  final SharedPreferences _prefs;

  WatchScoreRepository({SharedPreferences? prefs})
      : _prefs = prefs ?? throw StateError('Must initialize SharedPreferences');

  /// Save a score entry locally.
  Future<void> saveScoreEntry(WatchScoreEntry entry) async {
    final scores = await _getAllScores();
    scores.add(entry);
    await _prefs.setString(_scoresKey, _encodeScores(scores));
    await _addToPendingSync(entry);
  }

  /// Get all locally stored scores.
  Future<List<WatchScoreEntry>> getAllScores() async {
    return _getAllScores();
  }

  /// Get scores for a specific round.
  Future<List<WatchScoreEntry>> getScoresForRound(String? roundId) async {
    final scores = await _getAllScores();
    if (roundId == null) return scores;
    return scores.where((s) => s.roundId == roundId).toList();
  }

  /// Get scores for a specific player and hole.
  Future<WatchScoreEntry?> getScoreForHole(
    String playerId,
    int holeNumber, {
    String? roundId,
  }) async {
    final scores = await _getAllScores();
    return scores.cast<WatchScoreEntry?>().firstWhere(
          (s) =>
              s!.playerId == playerId &&
              s.holeNumber == holeNumber &&
              (roundId == null || s.roundId == roundId),
          orElse: () => null,
        );
  }

  /// Get pending sync entries (status = 'local' or 'pending').
  Future<List<WatchScoreEntry>> getPendingSyncEntries() async {
    final scores = await _getAllScores();
    return scores
        .where((s) => s.syncStatus == 'local' || s.syncStatus == 'pending')
        .toList();
  }

  /// Mark entry as synced.
  Future<void> markAsSynced(String entryId, {String? roundId}) async {
    final scores = await _getAllScores();
    final updated = scores.map((s) {
      if (s.id == entryId) {
        return s.copyWith(
          syncStatus: 'synced',
          roundId: roundId ?? s.roundId,
        );
      }
      return s;
    }).toList();
    await _prefs.setString(_scoresKey, _encodeScores(updated));
    await _removeFromPendingSync(entryId);
  }

  /// Mark entry as sync conflict.
  Future<void> markAsConflict(String entryId) async {
    final scores = await _getAllScores();
    final updated = scores.map((s) {
      if (s.id == entryId) {
        return s.copyWith(syncStatus: 'conflict');
      }
      return s;
    }).toList();
    await _prefs.setString(_scoresKey, _encodeScores(updated));
  }

  /// Save round session.
  Future<void> saveSession(WatchRoundSession session) async {
    await _prefs.setString(_sessionKey, jsonEncode(sessionToJson(session)));
  }

  /// Load round session.
  Future<WatchRoundSession?> loadSession() async {
    final jsonStr = _prefs.getString(_sessionKey);
    if (jsonStr == null) return null;
    try {
      return sessionFromJson(jsonDecode(jsonStr));
    } catch (_) {
      return null;
    }
  }

  /// Delete round session.
  Future<void> deleteSession() async {
    await _prefs.remove(_sessionKey);
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Future<List<WatchScoreEntry>> _getAllScores() async {
    final jsonStr = _prefs.getString(_scoresKey);
    if (jsonStr == null) return [];
    try {
      return _decodeScores(jsonStr);
    } catch (_) {
      return [];
    }
  }

  Future<void> _addToPendingSync(WatchScoreEntry entry) async {
    final pending = await getPendingSyncEntries();
    if (!pending.any((p) => p.id == entry.id)) {
      pending.add(entry.copyWith(syncStatus: 'pending'));
      await _prefs.setString(_pendingSyncKey, _encodeScores(pending));
    }
  }

  Future<void> _removeFromPendingSync(String entryId) async {
    final pending = await getPendingSyncEntries();
    pending.removeWhere((p) => p.id == entryId);
    await _prefs.setString(_pendingSyncKey, _encodeScores(pending));
  }

  String _encodeScores(List<WatchScoreEntry> scores) {
    return jsonEncode(scores.map((s) => scoreEntryToJson(s)).toList());
  }

  List<WatchScoreEntry> _decodeScores(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => scoreEntryFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> scoreEntryToJson(WatchScoreEntry entry) {
    return {
      'id': entry.id,
      'roundId': entry.roundId,
      'playerId': entry.playerId,
      'holeNumber': entry.holeNumber,
      'grossScore': entry.grossScore,
      'putts': entry.putts,
      'penalties': entry.penalties,
      'fairwayHit': entry.fairwayHit,
      'gir': entry.gir,
      'notes': entry.notes,
      'enteredAt': entry.enteredAt.toIso8601String(),
      'syncStatus': entry.syncStatus,
      'version': entry.version,
    };
  }

  WatchScoreEntry scoreEntryFromJson(Map<String, dynamic> json) {
    return WatchScoreEntry(
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
      syncStatus: json['syncStatus'] as String? ?? 'local',
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> sessionToJson(WatchRoundSession session) {
    return {
      'id': session.id,
      'roundId': session.roundId,
      'courseId': session.courseId,
      'courseName': session.courseName,
      'teeSetId': session.teeSetId,
      'currentHole': session.currentHole,
      'currentPar': session.currentPar,
      'totalHoles': session.totalHoles,
      'status': session.status.name,
      'gpsQuality': session.gpsQuality.name,
      'gpsAccuracyMeters': session.gpsAccuracyMeters,
      'hasGpsFix': session.hasGpsFix,
      'scores': session.scores.map((s) => holeScoreToJson(s)).toList(),
      'startedAt': session.startedAt.toIso8601String(),
      'updatedAt': session.updatedAt.toIso8601String(),
      'endedAt': session.endedAt?.toIso8601String(),
      'packageVersion': session.packageVersion,
      'syncStatus': session.syncStatus,
    };
  }

  WatchRoundSession sessionFromJson(Map<String, dynamic> json) {
    return WatchRoundSession(
      id: json['id'] as String,
      roundId: json['roundId'] as String?,
      courseId: json['courseId'] as int,
      courseName: json['courseName'] as String,
      teeSetId: json['teeSetId'] as String,
      currentHole: json['currentHole'] as int,
      currentPar: json['currentPar'] as int,
      totalHoles: json['totalHoles'] as int? ?? 18,
      status: WatchRoundStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => WatchRoundStatus.active,
      ),
      gpsQuality: WatchGpsQuality.values.firstWhere(
        (e) => e.name == json['gpsQuality'],
        orElse: () => WatchGpsQuality.unknown,
      ),
      gpsAccuracyMeters: (json['gpsAccuracyMeters'] as num?)?.toDouble() ?? 0,
      hasGpsFix: json['hasGpsFix'] as bool? ?? false,
      scores: (json['scores'] as List<dynamic>?)
              ?.map((e) => holeScoreFromJson(e as Map<String, dynamic>))
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
  }

  Map<String, dynamic> holeScoreToJson(WatchHoleScore score) {
    return {
      'playerId': score.playerId,
      'holeNumber': score.holeNumber,
      'strokes': score.strokes,
      'putts': score.putts,
      'penalties': score.penalties,
      'fairwayHit': score.fairwayHit,
      'gir': score.gir,
      'enteredAt': score.enteredAt?.toIso8601String(),
    };
  }

  WatchHoleScore holeScoreFromJson(Map<String, dynamic> json) {
    return WatchHoleScore(
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
  }
}
