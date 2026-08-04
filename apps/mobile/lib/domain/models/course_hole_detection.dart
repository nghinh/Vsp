// Course Hole Detection Models — VSP Mobile App
//
// Detection result, confidence level, and detection reason for
// automatic course/hole detection (story 6.2).
//
// Confidence scoring per architecture §2.1:
//   - Distance to tee-box centroid (weight: 0.3)
//   - Distance to green centroid (weight: 0.3)
//   - Heading alignment with hole direction (weight: 0.2)
//   - GPS accuracy signal (weight: 0.2)
//
// Story 6.2 — Wave A: Interface & Model Definitions

import 'package:equatable/equatable.dart';

/// Confidence level for automatic hole detection.
///
/// Auto-switch is only permitted at [ConfidenceLevel.high] or above
/// (confidence >= 0.6 per architecture §2.1).
enum ConfidenceLevel {
  /// 0.0 – 0.4: No auto-switch; prompt manual selection.
  low,

  /// 0.4 – 0.6: No auto-switch; show suggestion to user.
  medium,

  /// 0.6 – 0.8: Auto-switch enabled.
  high,

  /// 0.8 – 1.0: Auto-switch with confirmation toast.
  veryHigh;

  /// Human-readable label for UI display.
  String get displayLabel {
    switch (this) {
      case ConfidenceLevel.low:
        return 'Low Confidence';
      case ConfidenceLevel.medium:
        return 'Medium Confidence';
      case ConfidenceLevel.high:
        return 'High Confidence';
      case ConfidenceLevel.veryHigh:
        return 'Very High Confidence';
    }
  }

  /// Whether auto-switch is permitted at this confidence level.
  bool get canAutoSwitch =>
      this == ConfidenceLevel.high || this == ConfidenceLevel.veryHigh;

  /// Derive ConfidenceLevel from a numeric confidence score.
  static ConfidenceLevel fromScore(double score) {
    if (score >= 0.8) return ConfidenceLevel.veryHigh;
    if (score >= 0.6) return ConfidenceLevel.high;
    if (score >= 0.4) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}

/// Why the detection produced this result.
/// Used for observability and audit logging.
enum CourseHoleDetectionReason {
  /// First detection for this round or after app restart.
  initialDetection,

  /// Player moved from one hole to another.
  holeTransition,

  /// GPS accuracy improved and hole changed.
  accuracyImproved,

  /// Previously low-confidence detection now has sufficient confidence.
  confidenceCrossedThreshold,

  /// No facility found within search radius.
  noFacilityFound,

  /// Facility found but no course within it matched.
  noCourseFound,

  /// Facility and course found but no hole matched.
  noHoleFound,

  /// Detection was overridden by manual user selection.
  manualOverride,

  /// Detection was corrected from a wrong previous detection.
  correction,
}

/// Result of a single course/hole detection evaluation.
class CourseHoleDetectionResult extends Equatable {
  /// Detected facility ID. null if no facility found.
  final String? facilityId;

  /// Detected course ID. null if no course found.
  final String? courseId;

  /// Detected hole number (1–18). null if no hole found.
  final int? holeNumber;

  /// Detected tee-box ID. null if not determined.
  final String? teeBoxId;

  /// Detected green ID. null if not determined.
  final String? greenId;

  /// Confidence score 0.0–1.0.
  final double confidence;

  /// Confidence level bucket.
  final ConfidenceLevel level;

  /// True if auto-switch to this hole is permitted.
  /// Always false if [level] < [ConfidenceLevel.high].
  final bool canAutoSwitch;

  /// Why this detection was produced.
  final CourseHoleDetectionReason reason;

  /// Timestamp of detection.
  final DateTime detectedAt;

  const CourseHoleDetectionResult({
    this.facilityId,
    this.courseId,
    this.holeNumber,
    this.teeBoxId,
    this.greenId,
    required this.confidence,
    required this.level,
    required this.canAutoSwitch,
    required this.reason,
    required this.detectedAt,
  });

  /// True if a valid hole was detected (facility, course, and hole all present).
  bool get hasValidHole =>
      facilityId != null && courseId != null && holeNumber != null;

  /// True if no facility was found.
  bool get noFacility => facilityId == null;

  /// True if facility found but no course/hole matched.
  bool get noHoleMatch => facilityId != null && holeNumber == null;

  /// Human-readable description of the detection quality.
  String get qualityDescription {
    if (noFacility) return 'No nearby facility found';
    if (noHoleMatch) return 'Facility found but hole not detected';
    if (level == ConfidenceLevel.veryHigh) {
      return 'Very high confidence — auto-switch with confirmation';
    }
    if (level == ConfidenceLevel.high) {
      return 'High confidence — auto-switch enabled';
    }
    if (level == ConfidenceLevel.medium) {
      return 'Medium confidence — manual selection recommended';
    }
    return 'Low confidence — manual selection required';
  }

  factory CourseHoleDetectionResult.fromJson(Map<String, dynamic> json) {
    return CourseHoleDetectionResult(
      facilityId: json['facilityId'] as String?,
      courseId: json['courseId'] as String?,
      holeNumber: json['holeNumber'] as int?,
      teeBoxId: json['teeBoxId'] as String?,
      greenId: json['greenId'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      level: ConfidenceLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => ConfidenceLevel.low,
      ),
      canAutoSwitch: json['canAutoSwitch'] as bool,
      reason: CourseHoleDetectionReason.values.firstWhere(
        (r) => r.name == json['reason'],
        orElse: () => CourseHoleDetectionReason.initialDetection,
      ),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'facilityId': facilityId,
    'courseId': courseId,
    'holeNumber': holeNumber,
    'teeBoxId': teeBoxId,
    'greenId': greenId,
    'confidence': confidence,
    'level': level.name,
    'canAutoSwitch': canAutoSwitch,
    'reason': reason.name,
    'detectedAt': detectedAt.toIso8601String(),
  };

  CourseHoleDetectionResult copyWith({
    String? facilityId,
    String? courseId,
    int? holeNumber,
    String? teeBoxId,
    String? greenId,
    double? confidence,
    ConfidenceLevel? level,
    bool? canAutoSwitch,
    CourseHoleDetectionReason? reason,
    DateTime? detectedAt,
  }) {
    return CourseHoleDetectionResult(
      facilityId: facilityId ?? this.facilityId,
      courseId: courseId ?? this.courseId,
      holeNumber: holeNumber ?? this.holeNumber,
      teeBoxId: teeBoxId ?? this.teeBoxId,
      greenId: greenId ?? this.greenId,
      confidence: confidence ?? this.confidence,
      level: level ?? this.level,
      canAutoSwitch: canAutoSwitch ?? this.canAutoSwitch,
      reason: reason ?? this.reason,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }

  @override
  List<Object?> get props => [
    facilityId,
    courseId,
    holeNumber,
    teeBoxId,
    greenId,
    confidence,
    level,
    canAutoSwitch,
    reason,
    detectedAt,
  ];
}
