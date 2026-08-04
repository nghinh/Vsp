// CourseHoleDetection unit tests — VSP Mobile App
//
// Tests:
// - ConfidenceLevel.fromScore thresholds
// - ConfidenceLevel.canAutoSwitch
// - ConfidenceLevel.displayLabel
// - CourseHoleDetectionResult construction, computed properties
// - Serialization round-trip
// - CourseHoleDetectionReason enum
//
// Story 6.2 — Wave A

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/course_hole_detection.dart';

void main() {
  group('ConfidenceLevel', () {
    group('fromScore', () {
      test('returns low for score below 0.4', () {
        expect(ConfidenceLevel.fromScore(0.0), ConfidenceLevel.low);
        expect(ConfidenceLevel.fromScore(0.3), ConfidenceLevel.low);
        expect(ConfidenceLevel.fromScore(0.39), ConfidenceLevel.low);
      });

      test('returns medium for score 0.4-0.59', () {
        expect(ConfidenceLevel.fromScore(0.4), ConfidenceLevel.medium);
        expect(ConfidenceLevel.fromScore(0.5), ConfidenceLevel.medium);
        expect(ConfidenceLevel.fromScore(0.59), ConfidenceLevel.medium);
      });

      test('returns high for score 0.6-0.79', () {
        expect(ConfidenceLevel.fromScore(0.6), ConfidenceLevel.high);
        expect(ConfidenceLevel.fromScore(0.7), ConfidenceLevel.high);
        expect(ConfidenceLevel.fromScore(0.79), ConfidenceLevel.high);
      });

      test('returns veryHigh for score 0.8 and above', () {
        expect(ConfidenceLevel.fromScore(0.8), ConfidenceLevel.veryHigh);
        expect(ConfidenceLevel.fromScore(0.9), ConfidenceLevel.veryHigh);
        expect(ConfidenceLevel.fromScore(1.0), ConfidenceLevel.veryHigh);
      });
    });

    group('canAutoSwitch', () {
      test('returns false for low', () {
        expect(ConfidenceLevel.low.canAutoSwitch, false);
      });

      test('returns false for medium', () {
        expect(ConfidenceLevel.medium.canAutoSwitch, false);
      });

      test('returns true for high', () {
        expect(ConfidenceLevel.high.canAutoSwitch, true);
      });

      test('returns true for veryHigh', () {
        expect(ConfidenceLevel.veryHigh.canAutoSwitch, true);
      });
    });

    group('displayLabel', () {
      test('returns correct labels', () {
        expect(ConfidenceLevel.low.displayLabel, 'Low Confidence');
        expect(ConfidenceLevel.medium.displayLabel, 'Medium Confidence');
        expect(ConfidenceLevel.high.displayLabel, 'High Confidence');
        expect(ConfidenceLevel.veryHigh.displayLabel, 'Very High Confidence');
      });
    });
  });

  group('CourseHoleDetectionResult', () {
    group('construction', () {
      test('creates with all fields', () {
        final result = CourseHoleDetectionResult(
          facilityId: 'facility-1',
          courseId: 'course-1',
          holeNumber: 5,
          teeBoxId: 'tee-1',
          greenId: 'green-1',
          confidence: 0.75,
          level: ConfidenceLevel.high,
          canAutoSwitch: true,
          reason: CourseHoleDetectionReason.holeTransition,
          detectedAt: DateTime.parse('2026-08-02T10:00:00Z'),
        );

        expect(result.facilityId, 'facility-1');
        expect(result.courseId, 'course-1');
        expect(result.holeNumber, 5);
        expect(result.confidence, 0.75);
        expect(result.level, ConfidenceLevel.high);
        expect(result.canAutoSwitch, true);
        expect(result.reason, CourseHoleDetectionReason.holeTransition);
      });

      test('creates with null optional fields', () {
        final result = CourseHoleDetectionResult(
          confidence: 0.3,
          level: ConfidenceLevel.low,
          canAutoSwitch: false,
          reason: CourseHoleDetectionReason.noFacilityFound,
          detectedAt: DateTime.parse('2026-08-02T10:00:00Z'),
        );

        expect(result.facilityId, isNull);
        expect(result.courseId, isNull);
        expect(result.holeNumber, isNull);
        expect(result.teeBoxId, isNull);
        expect(result.greenId, isNull);
      });
    });

    group('computed properties', () {
      test('hasValidHole returns true when all required fields present', () {
        final result = CourseHoleDetectionResult(
          facilityId: 'facility-1',
          courseId: 'course-1',
          holeNumber: 5,
          confidence: 0.7,
          level: ConfidenceLevel.high,
          canAutoSwitch: true,
          reason: CourseHoleDetectionReason.initialDetection,
          detectedAt: DateTime.now(),
        );
        expect(result.hasValidHole, true);
      });

      test('hasValidHole returns false when holeNumber is null', () {
        final result = CourseHoleDetectionResult(
          facilityId: 'facility-1',
          courseId: 'course-1',
          confidence: 0.3,
          level: ConfidenceLevel.low,
          canAutoSwitch: false,
          reason: CourseHoleDetectionReason.noHoleFound,
          detectedAt: DateTime.now(),
        );
        expect(result.hasValidHole, false);
      });

      test('noFacility returns true when facilityId is null', () {
        final result = CourseHoleDetectionResult(
          confidence: 0.0,
          level: ConfidenceLevel.low,
          canAutoSwitch: false,
          reason: CourseHoleDetectionReason.noFacilityFound,
          detectedAt: DateTime.now(),
        );
        expect(result.noFacility, true);
      });

      test('noFacility returns false when facilityId is present', () {
        final result = CourseHoleDetectionResult(
          facilityId: 'facility-1',
          confidence: 0.3,
          level: ConfidenceLevel.low,
          canAutoSwitch: false,
          reason: CourseHoleDetectionReason.noHoleFound,
          detectedAt: DateTime.now(),
        );
        expect(result.noFacility, false);
      });

      test('noHoleMatch returns true when facility found but hole null', () {
        final result = CourseHoleDetectionResult(
          facilityId: 'facility-1',
          confidence: 0.3,
          level: ConfidenceLevel.low,
          canAutoSwitch: false,
          reason: CourseHoleDetectionReason.noHoleFound,
          detectedAt: DateTime.now(),
        );
        expect(result.noHoleMatch, true);
      });

      test('qualityDescription returns correct descriptions', () {
        final noFacilityResult = CourseHoleDetectionResult(
          confidence: 0.0,
          level: ConfidenceLevel.low,
          canAutoSwitch: false,
          reason: CourseHoleDetectionReason.noFacilityFound,
          detectedAt: DateTime.now(),
        );
        expect(noFacilityResult.qualityDescription, 'No nearby facility found');

        final veryHighResult = CourseHoleDetectionResult(
          facilityId: 'facility-1',
          courseId: 'course-1',
          holeNumber: 5,
          confidence: 0.85,
          level: ConfidenceLevel.veryHigh,
          canAutoSwitch: true,
          reason: CourseHoleDetectionReason.initialDetection,
          detectedAt: DateTime.now(),
        );
        expect(veryHighResult.qualityDescription,
            'Very high confidence — auto-switch with confirmation');
      });
    });

    group('fromJson / toJson round-trip', () {
      test('round-trip preserves all fields', () {
        final original = CourseHoleDetectionResult(
          facilityId: 'facility-1',
          courseId: 'course-1',
          holeNumber: 5,
          teeBoxId: 'tee-1',
          greenId: 'green-1',
          confidence: 0.75,
          level: ConfidenceLevel.high,
          canAutoSwitch: true,
          reason: CourseHoleDetectionReason.holeTransition,
          detectedAt: DateTime.parse('2026-08-02T10:00:00Z'),
        );

        final json = original.toJson();
        final restored = CourseHoleDetectionResult.fromJson(json);

        expect(restored.facilityId, original.facilityId);
        expect(restored.courseId, original.courseId);
        expect(restored.holeNumber, original.holeNumber);
        expect(restored.teeBoxId, original.teeBoxId);
        expect(restored.greenId, original.greenId);
        expect(restored.confidence, original.confidence);
        expect(restored.level, original.level);
        expect(restored.canAutoSwitch, original.canAutoSwitch);
        expect(restored.reason, original.reason);
      });

      test('fromJson defaults to low for unknown level', () {
        final json = {
          'confidence': 0.5,
          'level': 'unknown',
          'canAutoSwitch': false,
          'reason': 'initialDetection',
          'detectedAt': '2026-08-02T10:00:00.000Z',
        };

        final result = CourseHoleDetectionResult.fromJson(json);
        expect(result.level, ConfidenceLevel.low);
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final original = CourseHoleDetectionResult(
          facilityId: 'facility-1',
          courseId: 'course-1',
          holeNumber: 5,
          confidence: 0.75,
          level: ConfidenceLevel.high,
          canAutoSwitch: true,
          reason: CourseHoleDetectionReason.initialDetection,
          detectedAt: DateTime.parse('2026-08-02T10:00:00Z'),
        );

        final copied = original.copyWith(confidence: 0.9);

        expect(copied.facilityId, original.facilityId);
        expect(copied.confidence, 0.9);
        expect(copied.level, original.level);
      });
    });
  });

  group('CourseHoleDetectionReason enum', () {
    test('has expected values', () {
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.initialDetection));
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.holeTransition));
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.accuracyImproved));
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.confidenceCrossedThreshold));
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.noFacilityFound));
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.noCourseFound));
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.noHoleFound));
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.manualOverride));
      expect(CourseHoleDetectionReason.values, contains(CourseHoleDetectionReason.correction));
    });
  });
}
