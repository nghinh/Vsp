// This golfer's record of one hole — VSP Mobile App
//
// What they scored here before, and what they wrote about it. The scores say
// what happened; the note says why, and the why is the part that is lost
// between visits — a golfer works out on the fourth tee that the driver runs
// into the ditch, plays a 3-wood for the rest of the day, and comes back next
// month with a driver in their hand.

import 'package:vsp_mobile/core/network/api_client.dart';

class HoleAttempt {
  const HoleAttempt({
    required this.strokes,
    this.par,
    this.putts,
    this.toPar,
    this.playedAt,
  });

  final int strokes;
  final int? par;
  final int? putts;
  final int? toPar;
  final DateTime? playedAt;

  static HoleAttempt? parse(dynamic raw) {
    if (raw is! Map) return null;
    final strokes = raw['strokes'];
    if (strokes is! int) return null;
    return HoleAttempt(
      strokes: strokes,
      par: raw['par'] as int?,
      putts: raw['putts'] as int?,
      toPar: raw['toPar'] as int?,
      playedAt: DateTime.tryParse('${raw['playedAt'] ?? ''}'),
    );
  }
}

class HoleNote {
  const HoleNote({required this.id, required this.note, this.createdAt});

  final int id;
  final String note;
  final DateTime? createdAt;

  static HoleNote? parse(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final note = raw['note'];
    if (id is! int || note is! String || note.trim().isEmpty) return null;
    return HoleNote(
      id: id,
      note: note,
      createdAt: DateTime.tryParse('${raw['createdAt'] ?? ''}'),
    );
  }
}

class HoleHistory {
  const HoleHistory({
    required this.attempts,
    required this.notes,
    required this.timesPlayed,
    this.averageStrokes,
    this.bestStrokes,
  });

  final List<HoleAttempt> attempts;
  final List<HoleNote> notes;
  final int timesPlayed;

  /// Null rather than zero on a hole never played: "average 0.0" reads as a
  /// score, and a tee nobody has stood on should show nothing.
  final double? averageStrokes;
  final int? bestStrokes;

  bool get isEmpty => attempts.isEmpty && notes.isEmpty;

  static const empty = HoleHistory(
    attempts: [],
    notes: [],
    timesPlayed: 0,
  );

  static HoleHistory parse(dynamic json) {
    if (json is! Map<String, dynamic>) return empty;
    final scores = json['scores'];
    final notes = json['notes'];
    return HoleHistory(
      attempts: scores is List
          ? scores.map(HoleAttempt.parse).whereType<HoleAttempt>().toList()
          : const [],
      notes: notes is List
          ? notes.map(HoleNote.parse).whereType<HoleNote>().toList()
          : const [],
      timesPlayed: json['timesPlayed'] is int ? json['timesPlayed'] as int : 0,
      averageStrokes: (json['averageStrokes'] as num?)?.toDouble(),
      bestStrokes: json['bestStrokes'] as int?,
    );
  }
}

class HoleHistoryApi {
  HoleHistoryApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// This golfer's own record. Empty rather than an error when the server
  /// cannot be reached: a hole with no history looks the same as a hole whose
  /// history did not load, and neither should stop a golfer teeing off.
  Future<HoleHistory> forHole({
    required String courseId,
    required int holeNumber,
  }) async {
    try {
      final json = await _apiClient
          .get('/courses/$courseId/holes/$holeNumber/my-history');
      return HoleHistory.parse(json);
    } catch (_) {
      return HoleHistory.empty;
    }
  }

  /// Writes a note. Returns false when it did not reach the server, so the
  /// screen can say so rather than pretend it saved.
  Future<bool> addNote({
    required String courseId,
    required int holeNumber,
    required String note,
    String? roundId,
  }) async {
    try {
      await _apiClient.post(
        '/courses/$courseId/holes/$holeNumber/notes',
        body: {
          'note': note,
          if (roundId != null) 'roundId': roundId,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNote(int noteId) async {
    try {
      await _apiClient.delete('/hole-notes/$noteId');
      return true;
    } catch (_) {
      return false;
    }
  }
}
