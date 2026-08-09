// Green Position Reporter — VSP Mobile App
//
// Files "the green is here" from wherever the golfer is standing.
//
// ─── Why a one-tap path exists at all ────────────────────────────────────────
//
// Correcting course data already works: a form under the round's More menu
// collects an issue type, a layer, a note and a fix, and an admin reviews it on
// the portal. It is also three taps away from anywhere a golfer notices a
// problem, and it asks them to classify their complaint before they can report
// it.
//
// The single most valuable correction we can receive is a green position, and
// the app already knows exactly when to ask for one: it says, on the measuring
// panel, that the green position is estimated or missing. A golfer reading that
// sentence while standing on the putting surface is holding the answer. Turning
// that moment into one tap is the difference between a contribution flow that
// exists and one that gets used.
//
// ─── What this deliberately does not do ──────────────────────────────────────
//
// It does not touch the map. A submitted report is queued for review and the
// hole keeps drawing exactly what it drew before — same coordinates, same
// unsurveyed label. Letting a single unreviewed GPS fix move a green would
// undo the entire provenance gate: class D data would be arriving through a
// button instead of a pipeline, and the app would be showing a golfer their own
// guess back as course data.

import 'package:uuid/uuid.dart';

import '../../../data/repositories/course_correction_repository.dart';
import '../../../domain/models/qualified_location.dart';
import 'course_correction.dart';
import 'geometry_layer.dart';

/// Outcome of filing a green-position report.
enum GreenReportOutcome {
  /// Saved locally and queued for the server.
  queued,

  /// No fix, or one too coarse to be worth a reviewer's attention.
  noUsableFix,

  /// Storage or queue refused it. Nothing was recorded.
  failed,
}

/// Files a golfer's position as a proposed green position.
class GreenPositionReporter {
  /// Coarsest fix the correction API accepts (`gpsAccuracyMeters` <= 100).
  static const double maxAccuracyMeters = 100;

  final CourseCorrectionRepository _repository;
  final Uuid _uuid;

  GreenPositionReporter({
    required CourseCorrectionRepository repository,
    Uuid? uuid,
  }) : _repository = repository,
       _uuid = uuid ?? const Uuid();

  /// Records [location] as where the green is on [holeId] of [courseId].
  ///
  /// Writes to SQLite first and returns as soon as it is durable — a golfer
  /// four holes from a signal must not lose the report, and must not wait on a
  /// network call to see it acknowledged.
  Future<GreenReportOutcome> report({
    required String courseId,
    required String holeId,
    required QualifiedLocation? location,
    DateTime? now,
  }) async {
    final fix = location;
    if (fix == null ||
        fix.source == LocationSource.unavailable ||
        fix.accuracyMeters == null ||
        fix.accuracyMeters! > maxAccuracyMeters) {
      // A report pinned to a 300 m fix costs a reviewer the same attention as a
      // good one and tells them less than nothing.
      return GreenReportOutcome.noUsableFix;
    }

    final correction = CourseCorrection(
      id: _uuid.v4(),
      courseId: courseId,
      holeId: holeId,
      issueType: CorrectionIssueType.greenBoundary,
      layer: GeometryLayer.green,
      reporterLat: fix.latitude,
      reporterLng: fix.longitude,
      gpsAccuracy: fix.accuracyMeters!,
      submittedAt: (now ?? DateTime.now()).toUtc(),
      // No note. The panel that offered this said what the problem was, and
      // asking a golfer to type on a fairway is how a one-tap action stops
      // being one.
      note: null,
      syncState: CorrectionSyncState.pending,
      idempotencyKey: _uuid.v4(),
    );

    try {
      await _repository.submitCorrection(correction);
      return GreenReportOutcome.queued;
    } catch (_) {
      // Reported as a failure rather than swallowed: the golfer walked to the
      // green to do this, and "sent" over a dropped write is a worse outcome
      // than "try again".
      return GreenReportOutcome.failed;
    }
  }
}
