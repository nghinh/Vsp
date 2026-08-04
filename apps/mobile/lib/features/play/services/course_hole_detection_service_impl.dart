// CourseHoleDetectionServiceImpl — VSP Mobile App
//
// Mobile implementation of CourseHoleDetectionService.
// Orchestrates facility/course/hole detection using local repositories
// and the HoleDetectionScorer for weighted confidence scoring.
//
// Detection flow (architecture §2.2):
//   QualifiedLocation → FacilityRepository.findNearby → CourseRepository.findWithinFacility
//                   → HoleRepository.findByCourseWithGeometry → HoleDetectionScorer.scoreAll
//                   → CourseHoleDetectionResult
//
// Auto-switch policy:
//   confidence >= 0.6 → canAutoSwitch = true
//   confidence < 0.6  → canAutoSwitch = false
//
// Story 6.2 — Wave C: Detection Algorithm
// Story 6.2 — Wave E: Integration & Offline (cached detection)

import 'package:vsp_mobile/domain/models/course_hole_detection.dart';
import 'package:vsp_mobile/domain/models/manual_hole_selection.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/repositories/course_repository.dart';
import 'package:vsp_mobile/domain/repositories/facility_repository.dart';
import 'package:vsp_mobile/domain/repositories/hole_repository.dart';
import 'package:vsp_mobile/domain/services/course_hole_detection_service.dart';
import 'package:vsp_mobile/domain/services/hole_detection_scorer.dart';
import 'package:vsp_mobile/data/repositories/hole_selection_log_repository_impl.dart';

/// Mobile implementation of CourseHoleDetectionService.
///
/// Uses local repositories (SQLite-backed) for offline-first behavior.
/// Caches the last-known detection for restart recovery.
class CourseHoleDetectionServiceImpl implements CourseHoleDetectionService {
  final FacilityRepository _facilityRepository;
  final CourseRepository _courseRepository;
  final HoleRepository _holeRepository;
  final HoleDetectionScorer _scorer;
  final HoleSelectionLogRepository _selectionLogRepository;
  final DetectionCache _cache;

  /// Active round ID for the current detection context.
  String? _activeRoundId;

  /// Last detected result for the active round.
  CourseHoleDetectionResult? _lastResult;

  CourseHoleDetectionServiceImpl({
    required FacilityRepository facilityRepository,
    required CourseRepository courseRepository,
    required HoleRepository holeRepository,
    HoleDetectionScorer? scorer,
    HoleSelectionLogRepository? selectionLogRepository,
    DetectionCache? cache,
  }) : _facilityRepository = facilityRepository,
       _courseRepository = courseRepository,
       _holeRepository = holeRepository,
       _scorer = scorer ?? HoleDetectionScorer(),
       _selectionLogRepository =
           selectionLogRepository ?? HoleSelectionLogRepositoryImpl(),
       _cache = cache ?? DetectionCache();

  /// Set the active round context.
  /// Detection results are scoped to this round.
  void setActiveRound(String roundId) {
    _activeRoundId = roundId;
    // Load cached detection for this round
    _lastResult = _cache.get(roundId);
  }

  /// Clear the active round context.
  void clearActiveRound() {
    _activeRoundId = null;
    _lastResult = null;
  }

  @override
  Future<CourseHoleDetectionResult> detect({
    required QualifiedLocation location,
    required String roundId,
  }) async {
    // Set active round if not already set
    final previousRound = _activeRoundId;
    if (_activeRoundId != roundId) {
      setActiveRound(roundId);
    }

    // Check if location is usable for detection
    if (!location.isUsableForDetection) {
      final result = CourseHoleDetectionResult(
        confidence: 0.0,
        level: ConfidenceLevel.low,
        canAutoSwitch: false,
        reason: _determineNoDetectionReason(location),
        detectedAt: DateTime.now(),
      );
      _lastResult = result;
      _cache.put(roundId, result);
      return result;
    }

    // Step 1: Find nearby facility
    final facility = await _facilityRepository.findNearby(
      latitude: location.latitude,
      longitude: location.longitude,
      radiusMeters: 200,
    );

    if (facility == null) {
      final result = CourseHoleDetectionResult(
        confidence: 0.0,
        level: ConfidenceLevel.low,
        canAutoSwitch: false,
        reason: CourseHoleDetectionReason.noFacilityFound,
        detectedAt: DateTime.now(),
      );
      _lastResult = result;
      _cache.put(roundId, result);
      return result;
    }

    // Step 2: Find courses within the facility
    final courses = await _courseRepository.findWithinFacility(facility.id);
    if (courses.isEmpty) {
      final result = CourseHoleDetectionResult(
        facilityId: facility.id,
        confidence: 0.0,
        level: ConfidenceLevel.low,
        canAutoSwitch: false,
        reason: CourseHoleDetectionReason.noCourseFound,
        detectedAt: DateTime.now(),
      );
      _lastResult = result;
      _cache.put(roundId, result);
      return result;
    }

    // For MVP, use the first course at the facility
    // TODO(6.2): Handle multiple courses - detect which course based on hole positions
    final course = courses.first;

    // Step 3: Get hole geometries for scoring
    final holeGeometries = await _holeRepository.findByCourseWithGeometry(
      course.id,
    );
    if (holeGeometries.isEmpty) {
      final result = CourseHoleDetectionResult(
        facilityId: facility.id,
        courseId: course.id,
        confidence: 0.0,
        level: ConfidenceLevel.low,
        canAutoSwitch: false,
        reason: CourseHoleDetectionReason.noHoleFound,
        detectedAt: DateTime.now(),
      );
      _lastResult = result;
      _cache.put(roundId, result);
      return result;
    }

    // Step 4: Score all holes
    final scores = _scorer.scoreAll(
      location: location,
      holeGeometries: holeGeometries,
    );

    if (scores.isEmpty) {
      final result = CourseHoleDetectionResult(
        facilityId: facility.id,
        courseId: course.id,
        confidence: 0.0,
        level: ConfidenceLevel.low,
        canAutoSwitch: false,
        reason: CourseHoleDetectionReason.noHoleFound,
        detectedAt: DateTime.now(),
      );
      _lastResult = result;
      _cache.put(roundId, result);
      return result;
    }

    // Use the highest-scoring hole
    final bestScore = scores.first;
    final confidence = bestScore.score;
    final level = ConfidenceLevel.fromScore(confidence);
    final canAutoSwitch = level.canAutoSwitch;

    // Determine detection reason
    final reason = _determineDetectionReason(bestScore, _lastResult);

    final result = CourseHoleDetectionResult(
      facilityId: facility.id,
      courseId: course.id,
      holeNumber: bestScore.holeGeometry.holeNumber,
      teeBoxId:
          bestScore.holeGeometry.id, // tee box ID is the hole ID in our model
      greenId:
          bestScore.holeGeometry.id, // green ID is the hole ID in our model
      confidence: confidence,
      level: level,
      canAutoSwitch: canAutoSwitch,
      reason: reason,
      detectedAt: DateTime.now(),
    );

    _lastResult = result;
    _cache.put(roundId, result);

    return result;
  }

  @override
  Future<void> applyManualSelection({
    required QualifiedLocation location,
    required String roundId,
    required String selectedHoleId,
    required ManualSelectionReason reason,
  }) async {
    // Log the manual selection
    final selection = ManualHoleSelection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roundId: roundId,
      detectedHoleId: _lastResult?.holeNumber?.toString(),
      selectedHoleId: selectedHoleId,
      reason: reason,
      confidenceBefore: _lastResult?.confidence,
      locationAtSelection: location,
      selectedAt: DateTime.now(),
    );

    await _selectionLogRepository.append(selection);

    // Update last result to reflect manual selection
    if (_lastResult != null) {
      // Get the hole geometry to find the hole number
      final holeGeometry = await _holeRepository.getById(selectedHoleId);
      final holeNumber = holeGeometry?.holeNumber;

      _lastResult = _lastResult!.copyWith(
        holeNumber: holeNumber,
        reason: CourseHoleDetectionReason.manualOverride,
      );
      _cache.put(roundId, _lastResult!);
    }
  }

  @override
  Future<CourseHoleDetectionResult?> getLastKnownDetection(
    String roundId,
  ) async {
    return _cache.get(roundId);
  }

  /// Determine the reason for a no-detection result.
  CourseHoleDetectionReason _determineNoDetectionReason(
    QualifiedLocation location,
  ) {
    if (location.isStale) {
      return CourseHoleDetectionReason
          .noFacilityFound; // Stale location treated as no facility
    }
    if (location.isLowAccuracy) {
      return CourseHoleDetectionReason
          .noFacilityFound; // Low accuracy treated as no facility
    }
    return CourseHoleDetectionReason.noFacilityFound;
  }

  /// Determine the detection reason based on score and previous result.
  CourseHoleDetectionReason _determineDetectionReason(
    HoleScore score,
    CourseHoleDetectionResult? previous,
  ) {
    if (previous == null) {
      return CourseHoleDetectionReason.initialDetection;
    }

    // Check if hole changed
    if (previous.holeNumber != score.holeGeometry.holeNumber) {
      return CourseHoleDetectionReason.holeTransition;
    }

    // Check if confidence crossed threshold
    if (previous.level != ConfidenceLevel.high &&
        previous.level != ConfidenceLevel.veryHigh &&
        (score.score >= 0.6)) {
      return CourseHoleDetectionReason.confidenceCrossedThreshold;
    }

    // Check if accuracy improved significantly
    if (score.score > previous.confidence + 0.2) {
      return CourseHoleDetectionReason.accuracyImproved;
    }

    return CourseHoleDetectionReason.initialDetection;
  }
}

/// Simple in-memory cache for last-known detection per round.
///
/// For full offline persistence, this should be backed by SQLite.
/// TODO(6.2): Move to SQLite for crash-restart recovery.
class DetectionCache {
  final Map<String, CourseHoleDetectionResult> _cache = {};

  CourseHoleDetectionResult? get(String roundId) => _cache[roundId];

  void put(String roundId, CourseHoleDetectionResult result) {
    _cache[roundId] = result;
  }

  void remove(String roundId) {
    _cache.remove(roundId);
  }

  void clear() {
    _cache.clear();
  }
}
