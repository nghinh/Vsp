// CourseCorrectionDto — VSP Contracts Package
//
// API serialization model for CourseCorrection entity.
// Mirrors CourseCorrection domain model in
// apps/mobile/lib/features/correction/domain/course_correction.dart.
//
// Per Story 9.1: Submit Correction Offline.

/// Issue type DTO — mirrors [CorrectionIssueType] in mobile domain.
enum CorrectionIssueTypeDto {
  pinPosition,
  holeGeometry,
  hazardShape,
  greenBoundary,
  teePosition,
  fairwayShape,
  otherCourseData;

  static CorrectionIssueTypeDto fromString(String value) {
    return CorrectionIssueTypeDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => CorrectionIssueTypeDto.otherCourseData,
    );
  }
}

/// Sync state DTO — mirrors [CorrectionSyncState] in mobile domain.
enum CorrectionSyncStateDto {
  pending,
  submitted,
  accepted,
  rejected;

  static CorrectionSyncStateDto fromString(String value) {
    return CorrectionSyncStateDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => CorrectionSyncStateDto.pending,
    );
  }
}

/// CourseCorrection DTO for API request/response serialization.
///
/// Used as the request body when submitting a correction via the sync queue
/// and as the response body when the server acknowledges or updates state.
class CourseCorrectionDto {
  final String id;
  final String courseId;
  final String? holeId;
  final CorrectionIssueTypeDto issueType;
  final double reporterLat;
  final double reporterLng;
  final double gpsAccuracy;
  final DateTime submittedAt;
  final String? note;
  final CorrectionSyncStateDto syncState;
  final String idempotencyKey;

  const CourseCorrectionDto({
    required this.id,
    required this.courseId,
    this.holeId,
    required this.issueType,
    required this.reporterLat,
    required this.reporterLng,
    required this.gpsAccuracy,
    required this.submittedAt,
    this.note,
    this.syncState = CorrectionSyncStateDto.pending,
    required this.idempotencyKey,
  });

  /// Parse from API response JSON.
  factory CourseCorrectionDto.fromJson(Map<String, dynamic> json) {
    return CourseCorrectionDto(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      holeId: json['holeId'] as String?,
      issueType: CorrectionIssueTypeDto.fromString(
        json['issueType'] as String,
      ),
      reporterLat: (json['reporterLat'] as num).toDouble(),
      reporterLng: (json['reporterLng'] as num).toDouble(),
      gpsAccuracy: (json['gpsAccuracy'] as num).toDouble(),
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      note: json['note'] as String?,
      syncState: CorrectionSyncStateDto.fromString(
        json['syncState'] as String? ?? 'pending',
      ),
      idempotencyKey: json['idempotencyKey'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'holeId': holeId,
        'issueType': issueType.name,
        'reporterLat': reporterLat,
        'reporterLng': reporterLng,
        'gpsAccuracy': gpsAccuracy,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
        'note': note,
        'syncState': syncState.name,
        'idempotencyKey': idempotencyKey,
      };
}
