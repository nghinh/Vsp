// Stroke indexes for the games engine — VSP Mobile App
//
// Giving strokes in a match is the entire reason a stroke index exists, and
// the engine needs all of a round's indexes at once. A round composed of two
// nines needs both courses' — the back nine's hole 1 is the round's hole 10.

import 'package:vsp_mobile/core/network/api_client.dart';

class StrokeIndexApi {
  StrokeIndexApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// hole number → stroke index for one course. Empty is an answer: half the
  /// country's cards publish no index, and the engine plays gross rather than
  /// inventing an allocation.
  Future<Map<int, int>> forCourse(int courseId) async {
    final json = await _apiClient.get('/courses/$courseId/stroke-indexes');
    return (json as Map<String, dynamic>)
        .map((hole, si) => MapEntry(int.parse(hole), (si as num).toInt()));
  }

  /// The whole round's indexes, with the back nine shifted onto holes 10-18.
  ///
  /// Failure returns empty rather than throwing: a game that cannot fetch the
  /// index degrades to gross, which is what the flight would agree at the tee
  /// anyway.
  Future<Map<int, int>> forRound({
    required int courseId,
    int? backNineCourseId,
  }) async {
    try {
      final front = await forCourse(courseId);
      if (backNineCourseId == null) return front;
      final back = await forCourse(backNineCourseId);
      return {
        ...{for (final e in front.entries) if (e.key <= 9) e.key: e.value},
        ...{for (final e in back.entries) e.key + 9: e.value},
      };
    } catch (_) {
      return const {};
    }
  }
}
