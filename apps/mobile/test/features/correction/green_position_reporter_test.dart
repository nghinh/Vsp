// Tests for the one-tap "the green is here" report.
//
// The action sits next to the sentence where the app admits it does not know
// where the green is — the one moment a golfer is standing on the answer while
// reading the question. Everything here defends two properties of that
// shortcut: it must not file rubbish, and it must not be mistaken for a fix.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/repositories/course_correction_repository.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/domain/models/sync_status.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';
import 'package:vsp_mobile/features/correction/domain/geometry_layer.dart';
import 'package:vsp_mobile/features/correction/domain/green_position_reporter.dart';

class _Repository implements CourseCorrectionRepository {
  final List<CourseCorrection> submitted = [];
  final bool shouldThrow;

  _Repository({this.shouldThrow = false});

  @override
  Future<({CourseCorrection correction, SyncEvent syncEvent})> submitCorrection(
    CourseCorrection correction,
  ) async {
    if (shouldThrow) throw Exception('disk full');
    submitted.add(correction);
    return (
      correction: correction,
      syncEvent: SyncEvent(
        id: correction.idempotencyKey,
        type: SyncEventType.correctionSubmit,
        entityId: correction.id,
        payload: '{}',
        state: SyncStatus.pending,
        attemptCount: 0,
        createdAt: correction.submittedAt,
      ),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

QualifiedLocation fixAt({double accuracy = 4}) => QualifiedLocation(
  latitude: 10.85951,
  longitude: 106.9005933,
  accuracyMeters: accuracy,
  timestamp: DateTime.utc(2026, 8, 7, 7),
  source: LocationSource.gps,
  isStale: false,
);

void main() {
  Future<GreenReportOutcome> reportWith(
    _Repository repository, {
    QualifiedLocation? location,
    String holeId = '127',
  }) => GreenPositionReporter(repository: repository).report(
    courseId: '8',
    holeId: holeId,
    location: location,
  );

  group('a report worth a reviewer reading', () {
    test('is filed against the green layer of the named hole', () async {
      final repository = _Repository();

      final outcome = await reportWith(repository, location: fixAt());

      expect(outcome, GreenReportOutcome.queued);
      final filed = repository.submitted.single;
      expect(filed.layer, GeometryLayer.green);
      expect(filed.issueType, CorrectionIssueType.greenBoundary);
      // Hole 1 of Long Thành is row 127. Row 1 is hole 1 of a course in Hà
      // Nội, which is what corrections used to be filed against.
      expect(filed.holeId, '127');
      expect(filed.courseId, '8');
    });

    test('carries the golfer position and its accuracy', () async {
      final repository = _Repository();

      await reportWith(repository, location: fixAt(accuracy: 6.5));

      final filed = repository.submitted.single;
      expect(filed.reporterLat, closeTo(10.85951, 1e-9));
      expect(filed.reporterLng, closeTo(106.9005933, 1e-9));
      // The reviewer decides how much to trust the point; hiding the accuracy
      // would make every report look equally good.
      expect(filed.gpsAccuracy, 6.5);
    });

    test('is queued locally rather than sent', () async {
      final repository = _Repository();

      await reportWith(repository, location: fixAt());

      // Filed four holes from a signal. Waiting on the network would either
      // lose the report or hold the golfer on the green.
      expect(repository.submitted.single.syncState, CorrectionSyncState.pending);
      expect(repository.submitted.single.idempotencyKey, isNotEmpty);
    });

    test('two reports do not collide', () async {
      final repository = _Repository();

      await reportWith(repository, location: fixAt());
      await reportWith(repository, location: fixAt(), holeId: '128');

      final keys = repository.submitted.map((c) => c.idempotencyKey).toSet();
      expect(keys, hasLength(2));
    });
  });

  group('what is refused', () {
    test('a fix too coarse to place a green', () async {
      final repository = _Repository();

      final outcome = await reportWith(repository, location: fixAt(accuracy: 150));

      // Costs a reviewer the same attention as a good report and tells them
      // less than nothing.
      expect(outcome, GreenReportOutcome.noUsableFix);
      expect(repository.submitted, isEmpty);
    });

    test('no fix at all', () async {
      final repository = _Repository();

      final outcome = await reportWith(
        repository,
        location: QualifiedLocation.unavailable(),
      );

      expect(outcome, GreenReportOutcome.noUsableFix);
      expect(repository.submitted, isEmpty);
    });

    test('a missing location', () async {
      final repository = _Repository();

      expect(await reportWith(repository), GreenReportOutcome.noUsableFix);
    });
  });

  group('when the write fails', () {
    test('the golfer is told, not thanked', () async {
      final repository = _Repository(shouldThrow: true);

      final outcome = await reportWith(repository, location: fixAt());

      // They walked to the green to do this. "Sent" over a dropped write is
      // worse than "try again".
      expect(outcome, GreenReportOutcome.failed);
    });
  });
}

// ─── The queue, which nobody was filling ─────────────────────────────────────
//
// Kept in this file because it is the property the whole contribution flow
// rests on, and it was false for the entire life of the feature: the repository
// returned a SyncEvent and documented that "the UI layer dispatches it", and
// neither the correction form nor anything else ever did. Reports were written
// to the phone, confirmed on screen, and never sent. The server's corrections
// table was empty, which read as "golfers do not file corrections".
