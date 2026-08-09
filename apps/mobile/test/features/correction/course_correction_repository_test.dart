// Tests for a correction actually leaving the device.
//
// The repository used to write the correction to SQLite, build a SyncEvent,
// hand it back, and stop — with a comment saying the caller would queue it.
// Neither caller did. Every correction a golfer filed was saved locally,
// confirmed on screen with "Saved offline", and never sent; the server's
// corrections table stayed empty, which looked like golfers not using the
// feature rather than the feature not working.
//
// Both writes now happen here, because a repository that half-saves is a trap
// that the next caller will fall into too.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/local/daos/correction_dao.dart';
import 'package:vsp_mobile/data/repositories/course_correction_repository.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';
import 'package:vsp_mobile/features/correction/domain/geometry_layer.dart';
import 'package:vsp_mobile/infrastructure/persistence/sync_queue_repository.dart';

class _Dao implements CorrectionDao {
  final List<CourseCorrection> saved = [];

  @override
  Future<void> upsert(CourseCorrection correction) async =>
      saved.add(correction);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Queue implements SyncQueueRepository {
  final List<SyncEvent> appended = [];

  @override
  Future<void> append(SyncEvent event) async => appended.add(event);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CourseCorrection correctionFor(String id) => CourseCorrection(
  id: id,
  courseId: '8',
  holeId: '127',
  issueType: CorrectionIssueType.greenBoundary,
  layer: GeometryLayer.green,
  reporterLat: 10.85951,
  reporterLng: 106.9005933,
  gpsAccuracy: 4,
  submittedAt: DateTime.utc(2026, 8, 7, 7),
  syncState: CorrectionSyncState.pending,
  idempotencyKey: 'key-\$id',
);

void main() {
  test('a submitted correction is both stored and queued', () async {
    final dao = _Dao();
    final queue = _Queue();

    await CourseCorrectionRepositoryImpl(dao: dao, syncQueue: queue)
        .submitCorrection(correctionFor('c1'));

    expect(dao.saved, hasLength(1));
    // The half that was missing. Without it the golfer is told their report
    // was saved, and it was — to a table nothing reads.
    expect(queue.appended, hasLength(1));
    expect(queue.appended.single.type, SyncEventType.correctionSubmit);
  });

  test('the queued event carries the correction it belongs to', () async {
    final dao = _Dao();
    final queue = _Queue();

    await CourseCorrectionRepositoryImpl(dao: dao, syncQueue: queue)
        .submitCorrection(correctionFor('c2'));

    expect(queue.appended.single.entityId, 'c2');
  });

  test('a correction with no idempotency key is given one', () async {
    final dao = _Dao();
    final queue = _Queue();

    final result = await CourseCorrectionRepositoryImpl(
      dao: dao,
      syncQueue: queue,
    ).submitCorrection(
      correctionFor('c3').copyWith(idempotencyKey: ''),
    );

    // The server deduplicates on this header; an empty one turns a retry into
    // a duplicate report in the admin queue.
    expect(result.correction.idempotencyKey, isNotEmpty);
  });
}
