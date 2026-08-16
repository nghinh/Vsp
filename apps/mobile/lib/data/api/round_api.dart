// Round API — VSP Mobile App
//
// Client for the two round endpoints the play flow depends on:
//   POST /rounds                    — create the round when the golfer starts one
//   POST /rounds/{roundId}/complete — finish the round
//
// Both are idempotent server-side (Idempotency-Key header), so retrying after a
// flaky network never creates or completes a round twice.

import '../../core/network/api_client.dart';

/// A round as returned by the API (`RoundResponse`).
class RoundApiModel {
  final String id;
  final int courseId;
  final String? courseName;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? tournamentPolicyId;
  final String? tournamentId;
  final int? tournamentPolicyVersion;

  const RoundApiModel({
    required this.id,
    required this.courseId,
    this.courseName,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.tournamentPolicyId,
    this.tournamentId,
    this.tournamentPolicyVersion,
  });

  factory RoundApiModel.fromJson(Map<String, dynamic> json) {
    return RoundApiModel(
      id: json['id'].toString(),
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      courseName: json['courseName'] as String?,
      status: json['status'] as String? ?? 'IN_PROGRESS',
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now().toUtc(),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      tournamentPolicyId: json['tournamentPolicyId']?.toString(),
      tournamentId: json['tournamentId']?.toString(),
      tournamentPolicyVersion: (json['tournamentPolicyVersion'] as num?)
          ?.toInt(),
    );
  }
}

/// API client for round lifecycle calls. Throws [VspApiException] on failure.
class RoundApi {
  final ApiClient _apiClient;

  RoundApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Creates a round for the signed-in golfer.
  ///
  /// [playerIds] is omitted deliberately: the app's player list is local
  /// (guests have client-side ids), while the API expects golfer account ids.
  /// With no list the backend scores the authenticated golfer, which matches
  /// what the mobile scorecard syncs.
  Future<RoundApiModel> createRound({
    required int courseId,
    List<int> segmentCourseIds = const [],
    required String idempotencyKey,
    DateTime? startTime,
    int? packageId,
    bool cartRequested = false,
    String? tournamentPolicyId,
    String? tournamentId,
    String? format,
    bool? countsTowardHandicap,
  }) async {
    final body = <String, dynamic>{
      'courseId': courseId,
      // The đường played, in order. Sent only when it says something the
      // courseId cannot — a pairing of nines. The server defaults a missing
      // list to one segment, so an older build stays correct.
      if (segmentCourseIds.length > 1) 'segmentCourseIds': segmentCourseIds,
      'cartRequested': cartRequested,
      if (startTime != null) 'startTime': startTime.toUtc().toIso8601String(),
      if (packageId != null) 'packageId': packageId,
      // What kind of round this is, and whether it feeds the handicap the
      // app computes. The setup screen has asked the first question since it
      // existed; until now the answer never left the phone.
      if (format != null) 'format': format,
      if (countsTowardHandicap != null)
        'countsTowardHandicap': countsTowardHandicap,
      if (tournamentPolicyId != null) 'tournamentPolicyId': tournamentPolicyId,
      if (tournamentId != null) 'tournamentId': tournamentId,
    };

    final json = await _apiClient.post(
      '/rounds',
      body: body,
      idempotencyKey: idempotencyKey,
    );
    return RoundApiModel.fromJson(json as Map<String, dynamic>);
  }

  /// Marks a round complete. Safe to call again on an already-completed round.
  Future<RoundApiModel> completeRound({
    required String roundId,
    required String idempotencyKey,
  }) async {
    final json = await _apiClient.post(
      '/rounds/$roundId/complete',
      body: const {},
      idempotencyKey: idempotencyKey,
    );
    return RoundApiModel.fromJson(json as Map<String, dynamic>);
  }

  /// Abandons an in-progress round so it stops showing as "in progress".
  /// Safe to call again on an already-abandoned round.
  Future<RoundApiModel> abandonRound({
    required String roundId,
    required String idempotencyKey,
  }) async {
    final json = await _apiClient.post(
      '/rounds/$roundId/abandon',
      body: const {},
      idempotencyKey: idempotencyKey,
    );
    return RoundApiModel.fromJson(json as Map<String, dynamic>);
  }
}
