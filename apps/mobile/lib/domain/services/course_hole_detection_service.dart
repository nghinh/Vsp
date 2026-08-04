// Course Hole Detection Service Interface — VSP Mobile App
//
// Main orchestrator for automatic course and hole detection.
// Consumes [QualifiedLocation] from story 6.1 and produces
// [CourseHoleDetectionResult] for the UI layer.
//
// Detection flow (architecture §2.2):
//   QualifiedLocation → Facility filter → Course filter → Hole scoring → Result
//
// Auto-switch policy (architecture §2.1):
//   confidence >= 0.6 → canAutoSwitch = true
//   confidence < 0.6  → canAutoSwitch = false, manual selection required
//
// Story 6.2 — Wave A: Interface Definitions

import '../models/course_hole_detection.dart';
import '../models/manual_hole_selection.dart';
import '../models/qualified_location.dart';
import '../repositories/course_repository.dart';
import '../repositories/facility_repository.dart';
import '../repositories/hole_repository.dart';

/// Abstract interface for course/hole detection.
///
/// Implementations must:
/// - Use [FacilityRepository] to find nearby facilities (ST_DWithin 200m).
/// - Use [CourseRepository] to find the active course within the facility.
/// - Use [HoleRepository] to get hole geometries for scoring.
/// - Use [HoleDetectionScorer] for weighted multi-signal scoring.
/// - Respect confidence threshold: canAutoSwitch only when confidence >= 0.6.
/// - Log all [ManualHoleSelection] events for quality improvement.
///
/// Implementations:
/// - [CourseHoleDetectionServiceImpl] on mobile (Wave C).
abstract class CourseHoleDetectionService {
  /// Detect the current facility, course, and hole from a qualified location.
  ///
  /// [location] — Current GPS location from story 6.1.
  /// [roundId]  — Active round ID (for audit logging and round-context scoping).
  ///
  /// Returns a [CourseHoleDetectionResult] with:
  /// - Detected facility/course/hole IDs (if found)
  /// - Confidence score (0.0–1.0)
  /// - Confidence level bucket
  /// - canAutoSwitch flag
  /// - Detection reason
  ///
  /// Returns a no-facility result if nothing is found within the search radius.
  Future<CourseHoleDetectionResult> detect({
    required QualifiedLocation location,
    required String roundId,
  });

  /// Apply a manual hole selection and log it for audit.
  ///
  /// Called when the user explicitly chooses a hole (e.g., from hole picker).
  /// The selection is logged to [HoleSelectionLogRepository] for quality
  /// improvement per PRD §8.5.
  ///
  /// [location]     — Location at time of selection.
  /// [roundId]      — Active round ID.
  /// [selectedHoleId] — User-selected hole ID.
  /// [reason]       — Why the user made this selection.
  Future<void> applyManualSelection({
    required QualifiedLocation location,
    required String roundId,
    required String selectedHoleId,
    required ManualSelectionReason reason,
  });

  /// Get the cached last-known detection result for offline restart recovery.
  ///
  /// Returns null if no cached detection exists.
  Future<CourseHoleDetectionResult?> getLastKnownDetection(String roundId);
}
