// CourseCorrection unit tests — VSP Mobile App
//
// Tests cover:
// - CorrectionIssueType enum labels and fromString
// - CorrectionSyncState enum lifecycle and fromString
// - CourseCorrection construction with all required fields
// - SQLite round-trip: toMap / fromMap
// - JSON round-trip: toJson / fromJson
// - copyWith updates fields correctly
// - validate() returns no errors for valid correction
// - validate() returns errors for invalid correction
// - hasAcceptableAccuracy and accuracyLabel derived fields
//
// Per Story 9.1 Slice 1: Domain Model + DTO + SQLite.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';

void main() {
  final now = DateTime.now().toUtc();

  CourseCorrection buildValidCorrection() {
    return CourseCorrection(
      id: 'corr-001',
      courseId: 'course-001',
      holeId: 'hole-001',
      issueType: CorrectionIssueType.pinPosition,
      reporterLat: 10.762622,
      reporterLng: 106.660020,
      gpsAccuracy: 3.5,
      submittedAt: now,
      note: 'Pin was off by about 2 meters.',
      syncState: CorrectionSyncState.pending,
      idempotencyKey: 'idem-001',
    );
  }

  group('CorrectionIssueType', () {
    test('fromString returns correct enum value', () {
      expect(CorrectionIssueType.fromString('pinPosition'), CorrectionIssueType.pinPosition);
      expect(CorrectionIssueType.fromString('holeGeometry'), CorrectionIssueType.holeGeometry);
      expect(CorrectionIssueType.fromString('hazardShape'), CorrectionIssueType.hazardShape);
      expect(CorrectionIssueType.fromString('greenBoundary'), CorrectionIssueType.greenBoundary);
      expect(CorrectionIssueType.fromString('teePosition'), CorrectionIssueType.teePosition);
      expect(CorrectionIssueType.fromString('fairwayShape'), CorrectionIssueType.fairwayShape);
      expect(CorrectionIssueType.fromString('otherCourseData'), CorrectionIssueType.otherCourseData);
    });

    test('fromString is case-insensitive', () {
      expect(CorrectionIssueType.fromString('PINPOSITION'), CorrectionIssueType.pinPosition);
      expect(CorrectionIssueType.fromString('PinPosition'), CorrectionIssueType.pinPosition);
    });

    test('fromString returns otherCourseData for unknown value', () {
      expect(CorrectionIssueType.fromString('unknown'), CorrectionIssueType.otherCourseData);
      expect(CorrectionIssueType.fromString(''), CorrectionIssueType.otherCourseData);
    });

    test('label returns human-readable string', () {
      expect(CorrectionIssueType.pinPosition.label, 'Pin Position');
      expect(CorrectionIssueType.holeGeometry.label, 'Hole Geometry');
      expect(CorrectionIssueType.hazardShape.label, 'Hazard Shape');
      expect(CorrectionIssueType.greenBoundary.label, 'Green Boundary');
      expect(CorrectionIssueType.teePosition.label, 'Tee Position');
      expect(CorrectionIssueType.fairwayShape.label, 'Fairway Shape');
      expect(CorrectionIssueType.otherCourseData.label, 'Other Course Data');
    });
  });

  group('CorrectionSyncState', () {
    test('fromString returns correct enum value', () {
      expect(CorrectionSyncState.fromString('pending'), CorrectionSyncState.pending);
      expect(CorrectionSyncState.fromString('submitted'), CorrectionSyncState.submitted);
      expect(CorrectionSyncState.fromString('accepted'), CorrectionSyncState.accepted);
      expect(CorrectionSyncState.fromString('rejected'), CorrectionSyncState.rejected);
    });

    test('fromString is case-insensitive', () {
      expect(CorrectionSyncState.fromString('PENDING'), CorrectionSyncState.pending);
      expect(CorrectionSyncState.fromString('Pending'), CorrectionSyncState.pending);
    });

    test('fromString returns pending for unknown value', () {
      expect(CorrectionSyncState.fromString('unknown'), CorrectionSyncState.pending);
      expect(CorrectionSyncState.fromString(''), CorrectionSyncState.pending);
    });
  });

  group('CourseCorrection construction', () {
    test('creates correction with all required fields', () {
      final correction = buildValidCorrection();
      expect(correction.id, 'corr-001');
      expect(correction.courseId, 'course-001');
      expect(correction.holeId, 'hole-001');
      expect(correction.issueType, CorrectionIssueType.pinPosition);
      expect(correction.reporterLat, 10.762622);
      expect(correction.reporterLng, 106.660020);
      expect(correction.gpsAccuracy, 3.5);
      expect(correction.submittedAt, now);
      expect(correction.note, 'Pin was off by about 2 meters.');
      expect(correction.syncState, CorrectionSyncState.pending);
      expect(correction.idempotencyKey, 'idem-001');
    });

    test('creates correction without optional holeId', () {
      final correction = CourseCorrection(
        id: 'corr-002',
        courseId: 'course-001',
        holeId: null,
        issueType: CorrectionIssueType.otherCourseData,
        reporterLat: 10.762622,
        reporterLng: 106.660020,
        gpsAccuracy: 5.0,
        submittedAt: now,
        note: null,
        syncState: CorrectionSyncState.pending,
        idempotencyKey: 'idem-002',
      );
      expect(correction.holeId, null);
      expect(correction.note, null);
    });
  });

  group('CourseCorrection SQLite serialization', () {
    test('toMap produces correct snake_case keys', () {
      final correction = buildValidCorrection();
      final map = correction.toMap();
      expect(map.containsKey('id'), true);
      expect(map.containsKey('course_id'), true);
      expect(map.containsKey('hole_id'), true);
      expect(map.containsKey('issue_type'), true);
      expect(map.containsKey('reporter_lat'), true);
      expect(map.containsKey('reporter_lng'), true);
      expect(map.containsKey('gps_accuracy'), true);
      expect(map.containsKey('submitted_at'), true);
      expect(map.containsKey('note'), true);
      expect(map.containsKey('sync_state'), true);
      expect(map.containsKey('idempotency_key'), true);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final original = buildValidCorrection();
      final map = original.toMap();
      final restored = CourseCorrection.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.courseId, original.courseId);
      expect(restored.holeId, original.holeId);
      expect(restored.issueType, original.issueType);
      expect(restored.reporterLat, original.reporterLat);
      expect(restored.reporterLng, original.reporterLng);
      expect(restored.gpsAccuracy, original.gpsAccuracy);
      expect(restored.submittedAt.toUtc(), original.submittedAt.toUtc());
      expect(restored.note, original.note);
      expect(restored.syncState, original.syncState);
      expect(restored.idempotencyKey, original.idempotencyKey);
    });

    test('fromMap handles null holeId', () {
      final map = {
        'id': 'corr-003',
        'course_id': 'course-001',
        'hole_id': null,
        'issue_type': 'greenBoundary',
        'reporter_lat': 10.762622,
        'reporter_lng': 106.660020,
        'gps_accuracy': 4.0,
        'submitted_at': now.toIso8601String(),
        'note': null,
        'sync_state': 'pending',
        'idempotency_key': 'idem-003',
      };
      final correction = CourseCorrection.fromMap(map);
      expect(correction.holeId, null);
      expect(correction.note, null);
    });
  });

  group('CourseCorrection JSON serialization', () {
    test('toJson produces correct camelCase keys', () {
      final correction = buildValidCorrection();
      final json = correction.toJson();
      expect(json.containsKey('id'), true);
      expect(json.containsKey('courseId'), true);
      expect(json.containsKey('holeId'), true);
      expect(json.containsKey('issueType'), true);
      expect(json.containsKey('reporterLat'), true);
      expect(json.containsKey('reporterLng'), true);
      expect(json.containsKey('gpsAccuracy'), true);
      expect(json.containsKey('submittedAt'), true);
      expect(json.containsKey('note'), true);
      expect(json.containsKey('syncState'), true);
      expect(json.containsKey('idempotencyKey'), true);
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      final original = buildValidCorrection();
      final json = original.toJson();
      final restored = CourseCorrection.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.courseId, original.courseId);
      expect(restored.holeId, original.holeId);
      expect(restored.issueType, original.issueType);
      expect(restored.reporterLat, original.reporterLat);
      expect(restored.reporterLng, original.reporterLng);
      expect(restored.gpsAccuracy, original.gpsAccuracy);
      expect(restored.submittedAt.toUtc(), original.submittedAt.toUtc());
      expect(restored.note, original.note);
      expect(restored.syncState, original.syncState);
      expect(restored.idempotencyKey, original.idempotencyKey);
    });
  });

  group('CourseCorrection copyWith', () {
    test('copyWith updates specified fields', () {
      final original = buildValidCorrection();
      final updated = original.copyWith(
        syncState: CorrectionSyncState.submitted,
        note: 'Updated note',
      );

      expect(updated.id, original.id);
      expect(updated.syncState, CorrectionSyncState.submitted);
      expect(updated.note, 'Updated note');
      expect(updated.courseId, original.courseId);
    });

    test('copyWith clearHoleId removes holeId', () {
      final original = buildValidCorrection();
      final updated = original.copyWith(clearHoleId: true);
      expect(updated.holeId, null);
    });

    test('copyWith clearNote removes note', () {
      final original = buildValidCorrection();
      final updated = original.copyWith(clearNote: true);
      expect(updated.note, null);
    });
  });

  group('CourseCorrection validation', () {
    test('validate returns no errors for valid correction', () {
      final correction = buildValidCorrection();
      expect(correction.validate(), isEmpty);
      expect(correction.isValid, true);
    });

    test('validate returns error for empty courseId', () {
      final correction = CourseCorrection(
        id: 'corr-004',
        courseId: '',
        issueType: CorrectionIssueType.pinPosition,
        reporterLat: 10.762622,
        reporterLng: 106.660020,
        gpsAccuracy: 3.0,
        submittedAt: now,
        syncState: CorrectionSyncState.pending,
        idempotencyKey: 'idem-004',
      );
      expect(correction.validate(), contains('courseId is required'));
      expect(correction.isValid, false);
    });

    test('validate returns error for negative gpsAccuracy', () {
      final correction = CourseCorrection(
        id: 'corr-005',
        courseId: 'course-001',
        issueType: CorrectionIssueType.pinPosition,
        reporterLat: 10.762622,
        reporterLng: 106.660020,
        gpsAccuracy: -1.0,
        submittedAt: now,
        syncState: CorrectionSyncState.pending,
        idempotencyKey: 'idem-005',
      );
      expect(correction.validate(), contains('gpsAccuracy must be non-negative'));
      expect(correction.isValid, false);
    });

    test('validate returns error for note over 500 characters', () {
      final longNote = 'A' * 501;
      final correction = CourseCorrection(
        id: 'corr-006',
        courseId: 'course-001',
        issueType: CorrectionIssueType.pinPosition,
        reporterLat: 10.762622,
        reporterLng: 106.660020,
        gpsAccuracy: 3.0,
        submittedAt: now,
        note: longNote,
        syncState: CorrectionSyncState.pending,
        idempotencyKey: 'idem-006',
      );
      expect(correction.validate(), contains('Note must be 500 characters or fewer'));
      expect(correction.isValid, false);
    });

    test('validate accepts note at exactly 500 characters', () {
      final maxNote = 'A' * 500;
      final correction = CourseCorrection(
        id: 'corr-007',
        courseId: 'course-001',
        issueType: CorrectionIssueType.pinPosition,
        reporterLat: 10.762622,
        reporterLng: 106.660020,
        gpsAccuracy: 3.0,
        submittedAt: now,
        note: maxNote,
        syncState: CorrectionSyncState.pending,
        idempotencyKey: 'idem-007',
      );
      expect(correction.validate(), isEmpty);
      expect(correction.isValid, true);
    });
  });

  group('CourseCorrection derived fields', () {
    test('hasAcceptableAccuracy returns true when accuracy <= 10', () {
      expect(buildValidCorrection().hasAcceptableAccuracy, true);
    });

    test('hasAcceptableAccuracy returns false when accuracy > 10', () {
      final correction = buildValidCorrection().copyWith(gpsAccuracy: 15.0);
      expect(correction.hasAcceptableAccuracy, false);
    });

    test('accuracyLabel returns correct label', () {
      expect(buildValidCorrection().copyWith(gpsAccuracy: 3.0).accuracyLabel, 'High');
      expect(buildValidCorrection().copyWith(gpsAccuracy: 7.0).accuracyLabel, 'Good');
      expect(buildValidCorrection().copyWith(gpsAccuracy: 15.0).accuracyLabel, 'Moderate');
      expect(buildValidCorrection().copyWith(gpsAccuracy: 35.0).accuracyLabel, 'Low');
      expect(buildValidCorrection().copyWith(gpsAccuracy: 60.0).accuracyLabel, 'Poor');
    });
  });

  group('CourseCorrection equality', () {
    test('two corrections with same props are equal', () {
      final a = buildValidCorrection();
      final b = buildValidCorrection();
      expect(a, equals(b));
    });

    test('two corrections with different props are not equal', () {
      final a = buildValidCorrection();
      final b = buildValidCorrection().copyWith(id: 'different-id');
      expect(a, isNot(equals(b)));
    });
  });
}
