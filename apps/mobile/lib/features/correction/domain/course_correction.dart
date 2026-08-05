// CourseCorrection Domain Model — VSP Mobile App
//
// Per Story 9.1: Submit Correction Offline.
// Domain model for course-data quality corrections reported by golfers.
//
// Distinct from [Correction] in features/round/domain/correction.dart (score corrections).
//
// AC fields: issue type, course, hole, location, accuracy, timestamp, optional note,
// offline save, sync queue. Photo deferred to future iteration.

import 'package:equatable/equatable.dart';

import 'geometry_layer.dart';

/// Issue types for course-data quality corrections.
/// Covers the full course-data loop per story 9.1 AC.
enum CorrectionIssueType {
  pinPosition,
  holeGeometry,
  hazardShape,
  greenBoundary,
  teePosition,
  fairwayShape,
  otherCourseData;

  static CorrectionIssueType fromString(String value) {
    final normalized = value.toLowerCase();
    return CorrectionIssueType.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => CorrectionIssueType.otherCourseData,
    );
  }

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case CorrectionIssueType.pinPosition:
        return 'Pin Position';
      case CorrectionIssueType.holeGeometry:
        return 'Hole Geometry';
      case CorrectionIssueType.hazardShape:
        return 'Hazard Shape';
      case CorrectionIssueType.greenBoundary:
        return 'Green Boundary';
      case CorrectionIssueType.teePosition:
        return 'Tee Position';
      case CorrectionIssueType.fairwayShape:
        return 'Fairway Shape';
      case CorrectionIssueType.otherCourseData:
        return 'Other Course Data';
    }
  }
}

/// Local sync state for a [CourseCorrection].
///
/// Lifecycle: pending → submitted → accepted | rejected
enum CorrectionSyncState {
  /// Written to SQLite but not yet sent to the server.
  pending,

  /// Successfully sent to the server and acknowledged.
  submitted,

  /// Reviewed and accepted by course operator.
  accepted,

  /// Reviewed and rejected by course operator.
  rejected;

  static CorrectionSyncState fromString(String value) {
    return CorrectionSyncState.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => CorrectionSyncState.pending,
    );
  }
}

/// A course-data correction submitted by a golfer while on the course.
///
/// Written locally first (offline-first), then synced via the event queue.
/// The [idempotencyKey] is sent as the backend Idempotency-Key header.
class CourseCorrection extends Equatable {
  /// UUID — unique identifier for this correction.
  final String id;

  /// Course being corrected (course UUID from story 3).
  final String courseId;

  /// Hole being corrected, if applicable (hole UUID).
  /// Null when no active round or the issue spans the whole course.
  final String? holeId;

  /// What kind of issue is being reported.
  final CorrectionIssueType issueType;

  /// Which geometry layer of the hole is wrong (green, fairway, bunker,
  /// water, ob). Null for issue types that are not about a geometry layer.
  final GeometryLayer? layer;

  /// Reporter's latitude at time of submission (decimal degrees, WGS84).
  final double reporterLat;

  /// Reporter's longitude at time of submission (decimal degrees, WGS84).
  final double reporterLng;

  /// GPS horizontal accuracy at time of submission, in meters.
  final double gpsAccuracy;

  /// When the correction was submitted (UTC).
  final DateTime submittedAt;

  /// Optional free-text note (max 500 chars).
  final String? note;

  /// Current local sync state.
  final CorrectionSyncState syncState;

  /// UUID v4 idempotency key — stable across app restarts.
  /// Sent as Idempotency-Key header to the backend.
  final String idempotencyKey;

  const CourseCorrection({
    required this.id,
    required this.courseId,
    this.holeId,
    required this.issueType,
    this.layer,
    required this.reporterLat,
    required this.reporterLng,
    required this.gpsAccuracy,
    required this.submittedAt,
    this.note,
    required this.syncState,
    required this.idempotencyKey,
  });

  // ─── Derived ───────────────────────────────────────────────────────────────

  /// True if a location with acceptable accuracy was captured.
  bool get hasAcceptableAccuracy => gpsAccuracy <= 10.0;

  /// Human-readable accuracy label matching [QualifiedLocation.accuracyLabel].
  String get accuracyLabel {
    if (gpsAccuracy <= 5) return 'High';
    if (gpsAccuracy <= 10) return 'Good';
    if (gpsAccuracy <= 20) return 'Moderate';
    if (gpsAccuracy <= 50) return 'Low';
    return 'Poor';
  }

  // ─── Validation ───────────────────────────────────────────────────────────

  /// Validates fields and returns a list of errors (empty = valid).
  List<String> validate() {
    final errors = <String>[];
    if (courseId.isEmpty) errors.add('courseId is required');
    if (gpsAccuracy < 0) errors.add('gpsAccuracy must be non-negative');
    // A geometry-layer report is filed per hole; without one the API cannot
    // tell which feature the golfer is correcting.
    if (layer != null && (holeId == null || holeId!.isEmpty)) {
      errors.add('holeId is required for a geometry layer correction');
    }
    if (note != null && note!.length > 500) {
      errors.add('Note must be 500 characters or fewer');
    }
    return errors;
  }

  /// True if all validations pass.
  bool get isValid => validate().isEmpty;

  // ─── Copy ──────────────────────────────────────────────────────────────────

  CourseCorrection copyWith({
    String? id,
    String? courseId,
    String? holeId,
    CorrectionIssueType? issueType,
    GeometryLayer? layer,
    double? reporterLat,
    double? reporterLng,
    double? gpsAccuracy,
    DateTime? submittedAt,
    String? note,
    CorrectionSyncState? syncState,
    String? idempotencyKey,
    bool clearHoleId = false,
    bool clearNote = false,
    bool clearLayer = false,
  }) {
    return CourseCorrection(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      holeId: clearHoleId ? null : (holeId ?? this.holeId),
      issueType: issueType ?? this.issueType,
      layer: clearLayer ? null : (layer ?? this.layer),
      reporterLat: reporterLat ?? this.reporterLat,
      reporterLng: reporterLng ?? this.reporterLng,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      submittedAt: submittedAt ?? this.submittedAt,
      note: clearNote ? null : (note ?? this.note),
      syncState: syncState ?? this.syncState,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  // ─── SQLite serialization ─────────────────────────────────────────────────

  /// Convert to a Map for SQLite persistence (snake_case column names).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'hole_id': holeId,
      'issue_type': issueType.name,
      'layer': layer?.wireValue,
      'reporter_lat': reporterLat,
      'reporter_lng': reporterLng,
      'gps_accuracy': gpsAccuracy,
      'submitted_at': submittedAt.toUtc().toIso8601String(),
      'note': note,
      'sync_state': syncState.name,
      'idempotency_key': idempotencyKey,
    };
  }

  /// Reconstruct from a SQLite row.
  factory CourseCorrection.fromMap(Map<String, dynamic> map) {
    return CourseCorrection(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      holeId: map['hole_id'] as String?,
      issueType: CorrectionIssueType.fromString(map['issue_type'] as String),
      layer: GeometryLayer.fromString(map['layer'] as String?),
      reporterLat: (map['reporter_lat'] as num).toDouble(),
      reporterLng: (map['reporter_lng'] as num).toDouble(),
      gpsAccuracy: (map['gps_accuracy'] as num).toDouble(),
      submittedAt: DateTime.parse(map['submitted_at'] as String),
      note: map['note'] as String?,
      syncState: CorrectionSyncState.fromString(map['sync_state'] as String),
      idempotencyKey: map['idempotency_key'] as String,
    );
  }

  // ─── JSON serialization ───────────────────────────────────────────────────

  /// Parse from API JSON (camelCase DTO format).
  factory CourseCorrection.fromJson(Map<String, dynamic> json) {
    return CourseCorrection(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      holeId: json['holeId'] as String?,
      issueType: CorrectionIssueType.fromString(json['issueType'] as String),
      layer: GeometryLayer.fromString(json['layer'] as String?),
      reporterLat: (json['reporterLat'] as num).toDouble(),
      reporterLng: (json['reporterLng'] as num).toDouble(),
      gpsAccuracy: (json['gpsAccuracy'] as num).toDouble(),
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      note: json['note'] as String?,
      syncState: CorrectionSyncState.fromString(
        json['syncState'] as String? ?? 'pending',
      ),
      idempotencyKey: json['idempotencyKey'] as String,
    );
  }

  /// Convert to API JSON (camelCase).
  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'holeId': holeId,
    'issueType': issueType.name,
    'layer': layer?.wireValue,
    'reporterLat': reporterLat,
    'reporterLng': reporterLng,
    'gpsAccuracy': gpsAccuracy,
    'submittedAt': submittedAt.toUtc().toIso8601String(),
    'note': note,
    'syncState': syncState.name,
    'idempotencyKey': idempotencyKey,
  };

  /// Body for `POST /courses/{courseId}/geometry-corrections`.
  ///
  /// The reported shape is the golfer's own position as a GeoJSON Point: the
  /// hole map is a MapLibre GL surface with no polygon-drawing tool, so a
  /// golfer standing on the misplaced edge marks the spot rather than tracing
  /// the feature. The endpoint accepts a Polygon too, for when an editor can
  /// send one.
  Map<String, dynamic> toGeometryCorrectionRequest() => {
    'holeId': int.tryParse(holeId ?? ''),
    'layer': layer?.wireValue,
    'geometry': {
      'type': 'Point',
      'coordinates': [reporterLng, reporterLat],
    },
    'gpsAccuracyMeters': gpsAccuracy,
    'reporterLat': reporterLat,
    'reporterLng': reporterLng,
    if (note != null && note!.isNotEmpty) 'note': note,
  };

  @override
  List<Object?> get props => [
    id,
    courseId,
    holeId,
    issueType,
    layer,
    reporterLat,
    reporterLng,
    gpsAccuracy,
    submittedAt,
    note,
    syncState,
    idempotencyKey,
  ];
}
