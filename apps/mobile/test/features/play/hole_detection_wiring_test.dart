// Tests for the round following the golfer across the course.
//
// Story 6.2 says the app detects the facility, the course and the likely hole.
// CourseHoleDetectionServiceImpl (318 LOC), DetectionCubit (340 LOC),
// HoleDetectionScorer and a confirmation dialog were all written, and every one
// of them was constructed only inside its own file — so on an eighteen-hole
// round the golfer moved the map by hand, eighteen times.
//
// The gate below is the part that matters most, and it is why wiring this was
// not simply "call the service". Detection scores a position against a hole's
// tee and green points. In this database those points are usually generated:
// the tee is a clubhouse pin walked along a fixed 0.0008°/0.0006° diagonal and
// the green sits exactly `playing_length_meters` due north of it. Scoring
// against that does not produce a weak answer, it produces a confident wrong
// one — eighteen holes in a tidy row near the car park — and it would move a
// golfer to the wrong hole mid-round and take their scorecard with it.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/course_hole_detection.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/domain/models/manual_hole_selection.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/repositories/course_repository.dart';
import 'package:vsp_mobile/domain/repositories/facility_repository.dart';
import 'package:vsp_mobile/domain/repositories/hole_repository.dart';
import 'package:vsp_mobile/domain/services/course_hole_detection_service.dart';
import 'package:vsp_mobile/application/detection/detection_cubit.dart';
import 'package:vsp_mobile/application/location/location_state.dart';
import 'package:vsp_mobile/features/play/services/course_hole_detection_service_impl.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _StubFacilityRepository implements FacilityRepository {
  @override
  Future<FacilitySearchResult?> findNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 200,
  }) async => const FacilitySearchResult(
    id: 'facility-1',
    name: 'Test facility',
    latitude: 10.7,
    longitude: 106.7,
  );

  @override
  Future<FacilitySearchResult?> getById(String facilityId) async => null;
}

class _StubCourseRepository implements CourseRepository {
  @override
  Future<List<CourseSearchResult>> findWithinFacility(
    String facilityId,
  ) async => const [
    CourseSearchResult(id: 'course-1', name: 'North', holeCount: 18),
  ];

  @override
  Future<CourseSearchResult?> getById(String courseId) async => null;
}

class _StubHoleRepository implements HoleRepository {
  final List<HoleGeometry> holes;

  _StubHoleRepository(this.holes);

  @override
  Future<List<HoleGeometry>> findByCourseWithGeometry(String courseId) async =>
      holes;

  @override
  Future<HoleGeometry?> getById(String holeId) async => holes
      .cast<HoleGeometry?>()
      .firstWhere((h) => h?.id == holeId, orElse: () => null);
}

/// A detector the test drives directly, so the round's reaction can be tested
/// without reproducing the scorer's geometry maths.
class _ScriptedDetector implements CourseHoleDetectionService {
  CourseHoleDetectionResult next;

  _ScriptedDetector(this.next);

  @override
  Future<CourseHoleDetectionResult> detect({
    required QualifiedLocation location,
    required String roundId,
  }) async => next;

  @override
  Future<void> applyManualSelection({
    required QualifiedLocation location,
    required String roundId,
    required String selectedHoleId,
    required ManualSelectionReason reason,
  }) async {}

  @override
  Future<CourseHoleDetectionResult?> getLastKnownDetection(
    String roundId,
  ) async => null;
}

// ─── Builders ───────────────────────────────────────────────────────────────

QualifiedLocation _fix() => QualifiedLocation(
  latitude: 10.7,
  longitude: 106.7,
  accuracyMeters: 4,
  timestamp: DateTime.now(),
  source: LocationSource.gps,
  isStale: false,
);

HoleGeometry _hole(int number, {required bool surveyed}) => HoleGeometry(
  id: '$number',
  holeNumber: number,
  par: 4,
  teeBoxLatitude: 10.700 + number * 0.0006,
  teeBoxLongitude: 106.700 + number * 0.0008,
  greenLatitude: 10.703 + number * 0.0006,
  greenLongitude: 106.700 + number * 0.0008,
  holeDirectionBearing: 0,
  provenance: surveyed
      ? const HoleDataProvenance(
          accuracyClass: AccuracyClass.classC,
          verificationStatus: VerificationStatus.verified,
        )
      : const HoleDataProvenance(
          accuracyClass: AccuracyClass.classD,
          verificationStatus: VerificationStatus.unverified,
          source: 'synthetic:seed-arithmetic',
        ),
);

CourseHoleDetectionResult _detected(
  int hole, {
  required double confidence,
  required bool canAutoSwitch,
}) => CourseHoleDetectionResult(
  facilityId: 'facility-1',
  courseId: 'course-1',
  holeNumber: hole,
  confidence: confidence,
  level: canAutoSwitch ? ConfidenceLevel.high : ConfidenceLevel.low,
  canAutoSwitch: canAutoSwitch,
  reason: CourseHoleDetectionReason.holeTransition,
  detectedAt: DateTime.now(),
);

void main() {
  group('the provenance gate', () {
    test('refuses to score holes nobody verified', () async {
      final service = CourseHoleDetectionServiceImpl(
        facilityRepository: _StubFacilityRepository(),
        courseRepository: _StubCourseRepository(),
        holeRepository: _StubHoleRepository([
          for (var i = 1; i <= 18; i++) _hole(i, surveyed: false),
        ]),
      );

      final result = await service.detect(location: _fix(), roundId: 'round-1');

      // Distinct from noHoleFound: the course does cover the golfer, and the
      // app does not trust its own map of it.
      expect(result.reason, CourseHoleDetectionReason.holeDataUnverified);
      expect(result.holeNumber, isNull);
      expect(result.canAutoSwitch, isFalse);
      expect(result.confidence, 0.0);
    });

    test('scores a hole somebody did verify', () async {
      final service = CourseHoleDetectionServiceImpl(
        facilityRepository: _StubFacilityRepository(),
        courseRepository: _StubCourseRepository(),
        holeRepository: _StubHoleRepository([
          for (var i = 1; i <= 18; i++) _hole(i, surveyed: true),
        ]),
      );

      final result = await service.detect(location: _fix(), roundId: 'round-1');

      expect(
        result.reason,
        isNot(CourseHoleDetectionReason.holeDataUnverified),
      );
      expect(result.holeNumber, isNotNull);
    });

    test('ignores the unverified holes on a partly digitised course', () async {
      // A course can hold sixteen digitised holes and two the seed invented.
      final service = CourseHoleDetectionServiceImpl(
        facilityRepository: _StubFacilityRepository(),
        courseRepository: _StubCourseRepository(),
        holeRepository: _StubHoleRepository([
          _hole(1, surveyed: true),
          _hole(2, surveyed: false),
          _hole(3, surveyed: true),
        ]),
      );

      final result = await service.detect(location: _fix(), roundId: 'round-1');

      expect(result.holeNumber, isNot(2));
    });
  });

  group('the cubit a round listens to', () {
    // The round's reaction is a BlocListener over these states: above the
    // threshold it moves, below it the golfer is asked. Asserted here rather
    // than through the round's widget tree — that tree keeps a GPS stream, a
    // detection subscription and the scorecard's SQLite load alive, and the
    // test binding will not tear it down. What is *not* covered by a test, and
    // should be: that the round moves the scorecard when this fires.
    late _ScriptedDetector detector;
    late DetectionCubit cubit;
    late StreamController<LocationState> locations;

    setUp(() async {
      detector = _ScriptedDetector(
        _detected(7, confidence: 0.2, canAutoSwitch: false),
      );
      cubit = DetectionCubit(detectionService: detector);
      locations = StreamController<LocationState>.broadcast();
      await cubit.startDetection('round-1', locations.stream);
    });

    tearDown(() async {
      await cubit.stopDetection();
      await cubit.close();
      await locations.close();
    });

    Future<void> arrive(CourseHoleDetectionResult result) async {
      detector.next = result;
      locations.add(
        LocationState(
          status: LocationServiceStatus.active,
          currentLocation: _fix(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('a confident detection is one the round may act on alone', () async {
      // Seed the previous hole, so the next arrival is a transition.
      await arrive(_detected(7, confidence: 0.9, canAutoSwitch: true));
      await arrive(_detected(8, confidence: 0.9, canAutoSwitch: true));

      expect(cubit.state.currentDetection?.holeNumber, 8);
      expect(cubit.state.canAutoSwitch, isTrue);
      expect(cubit.state.pendingSwitch, isFalse);
    });

    test('an uncertain detection asks instead', () async {
      await arrive(_detected(7, confidence: 0.9, canAutoSwitch: true));
      await arrive(_detected(8, confidence: 0.35, canAutoSwitch: false));

      // Below 0.6 the round must not move on its own: walking a golfer to the
      // wrong hole mid-round takes their scorecard with it.
      expect(cubit.state.canAutoSwitch, isFalse);
      expect(cubit.state.pendingSwitch, isTrue);
      expect(cubit.state.suggestedHoleNumber, 8);
    });

    test('staying on the same hole asks nothing', () async {
      await arrive(_detected(7, confidence: 0.4, canAutoSwitch: false));
      await arrive(_detected(7, confidence: 0.4, canAutoSwitch: false));

      expect(cubit.state.pendingSwitch, isFalse);
    });
  });
}
