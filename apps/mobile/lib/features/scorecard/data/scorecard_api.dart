// Scorecard submission — VSP Mobile App
//
// Stroke index is printed on the club's card and exists in no open dataset.
// The golfer holding that card is the only source there is, so the app's job
// is to carry what they read off it — whole, and unedited — into the review
// queue an admin already works.

import '../../../core/network/api_client.dart';

/// One numbered line of a club's card.
class ScorecardLine {
  const ScorecardLine({
    required this.hole,
    required this.par,
    this.strokeIndex,
  });

  final int hole;
  final int par;
  final int? strokeIndex;

  Map<String, dynamic> toJson() => {
    'hole': hole,
    'par': par,
    if (strokeIndex != null) 'strokeIndex': strokeIndex,
  };
}

/// What a submitted card must satisfy before it is worth an admin's time.
///
/// The server checks all of this too — it has to, since nothing stops another
/// client — but a golfer typing eighteen lines off a photograph should be told
/// which line is wrong while the card is still in their hand, not after a
/// round trip that answers "422".
class ScorecardValidation {
  const ScorecardValidation._(this.error);

  final String? error;

  bool get isValid => error == null;

  static const ScorecardValidation ok = ScorecardValidation._(null);

  static ScorecardValidation of(String error) => ScorecardValidation._(error);
}

class ScorecardApi {
  ScorecardApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Queue a card for review. Returns the correction id.
  Future<int> submit({
    required int courseId,
    required String name,
    required List<int> segmentCourseIds,
    required List<ScorecardLine> holes,
    required String idempotencyKey,
    List<Map<String, dynamic>> tees = const [],
    String? evidenceUrl,
    String? note,
  }) async {
    final json = await _apiClient.post(
      '/courses/$courseId/scorecard-corrections',
      idempotencyKey: idempotencyKey,
      body: {
        'name': name,
        'segmentCourseIds': segmentCourseIds,
        'holes': holes.map((h) => h.toJson()).toList(),
        // Omitted rather than sent empty: a card photographed with its rating
        // table outside the frame has no tee rows, and an empty list would
        // read as "this club prints none".
        if (tees.isNotEmpty) 'tees': tees,
        if (evidenceUrl != null && evidenceUrl.isNotEmpty)
          'evidenceUrl': evidenceUrl,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return (json as Map<String, dynamic>)['correctionId'] as int;
  }
}
