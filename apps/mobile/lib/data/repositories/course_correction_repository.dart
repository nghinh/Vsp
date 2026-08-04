// CourseCorrectionRepository — VSP Mobile App
//
// Offline-first repository for CourseCorrection entities.
//
// Per Story 9.1 Slice 2: Sync Event Extension + Repository.
// - submitCorrection: writes locally, returns a pending SyncEvent for the sync worker.
// - Query methods delegate to CorrectionDao.
// - Sync state hooks update local correction state when server confirms or updates.

import 'package:uuid/uuid.dart';

import '../../features/correction/domain/course_correction.dart';
import '../local/daos/correction_dao.dart';
import '../../domain/models/sync_event.dart';
import '../../domain/models/sync_status.dart';

/// Abstract interface for CourseCorrection persistence and sync.
///
/// The repository follows offline-first semantics: writes go to SQLite first,
/// then a SyncEvent is queued for the sync worker to deliver to the backend.
abstract class CourseCorrectionRepository {
  /// Submit a new correction.
  ///
  /// Writes to SQLite immediately (offline-first) and returns a pending
  /// [SyncEvent] that will be picked up by the sync worker.
  ///
  /// The [correction] must have [CorrectionSyncState.pending].
  /// After calling this, the caller should dispatch the returned SyncEvent
  /// to the sync queue.
  Future<({CourseCorrection correction, SyncEvent syncEvent})> submitCorrection(
    CourseCorrection correction,
  );

  /// Get all corrections with a specific sync state.
  Future<List<CourseCorrection>> getCorrectionsByState(
    CorrectionSyncState state,
  );

  /// Get all corrections for a specific course.
  Future<List<CourseCorrection>> getCorrectionsForCourse(String courseId);

  /// Get a correction by ID.
  Future<CourseCorrection?> getCorrectionById(String id);

  /// Update the sync state of a correction by ID.
  Future<void> updateCorrectionSyncState(String id, CorrectionSyncState state);

  /// Called by the sync worker when a correctionSubmit event is confirmed
  /// by the server (2xx). Transitions: pending → submitted.
  Future<void> onSyncComplete(String idempotencyKey);

  /// Called when the server pushes or the client polls for correction status
  /// updates (accepted/rejected). Transitions: submitted → accepted|rejected.
  Future<void> onServerStatusUpdate(
    String correctionId,
    CorrectionSyncState state,
  );
}

/// SQLite-backed implementation of [CourseCorrectionRepository].
class CourseCorrectionRepositoryImpl implements CourseCorrectionRepository {
  final CorrectionDao _dao;
  final Uuid _uuid;

  CourseCorrectionRepositoryImpl({CorrectionDao? dao, Uuid? uuid})
    : _dao = dao ?? CorrectionDao(),
      _uuid = uuid ?? const Uuid();

  @override
  Future<({CourseCorrection correction, SyncEvent syncEvent})> submitCorrection(
    CourseCorrection correction,
  ) async {
    // Ensure the correction has an idempotency key.
    final idempotencyKey = correction.idempotencyKey.isEmpty
        ? _uuid.v4()
        : correction.idempotencyKey;

    final pendingCorrection = correction.copyWith(
      syncState: CorrectionSyncState.pending,
      idempotencyKey: idempotencyKey,
    );

    // Write to SQLite (offline-first).
    await _dao.upsert(pendingCorrection);

    // Build the sync event.
    final syncEvent = SyncEvent.forCorrection(
      correctionId: pendingCorrection.id,
      correctionPayload: pendingCorrection.toJson(),
    );

    return (correction: pendingCorrection, syncEvent: syncEvent);
  }

  @override
  Future<List<CourseCorrection>> getCorrectionsByState(
    CorrectionSyncState state,
  ) async {
    return _dao.getBySyncState(state);
  }

  @override
  Future<List<CourseCorrection>> getCorrectionsForCourse(
    String courseId,
  ) async {
    return _dao.getByCourseId(courseId);
  }

  @override
  Future<CourseCorrection?> getCorrectionById(String id) async {
    return _dao.getById(id);
  }

  @override
  Future<void> updateCorrectionSyncState(
    String id,
    CorrectionSyncState state,
  ) async {
    await _dao.updateSyncState(id, state);
  }

  @override
  Future<void> onSyncComplete(String idempotencyKey) async {
    // Look up the correction by idempotency key and transition pending → submitted.
    final correction = await _dao.getByIdempotencyKey(idempotencyKey);
    if (correction == null) return;

    if (correction.syncState == CorrectionSyncState.pending) {
      await _dao.updateSyncState(correction.id, CorrectionSyncState.submitted);
    }
  }

  @override
  Future<void> onServerStatusUpdate(
    String correctionId,
    CorrectionSyncState state,
  ) async {
    // Only accept accepted or rejected from the server.
    if (state != CorrectionSyncState.accepted &&
        state != CorrectionSyncState.rejected) {
      return;
    }
    await _dao.updateSyncState(correctionId, state);
  }
}
