// HoleSelectionLogRepositoryImpl — VSP Mobile App
//
// SQLite-backed implementation of HoleSelectionLogRepository.
// Provides append-only persistence for manual hole selection audit log.
//
// Story 6.2 — Wave D: Manual Override & Audit

import '../../domain/models/manual_hole_selection.dart';
import '../local/daos/hole_selection_log_dao.dart';

/// Abstract repository interface for hole selection log persistence.
///
/// Used by CourseHoleDetectionServiceImpl to log manual hole selections
/// and overrides for quality improvement (PRD §8.5).
abstract class HoleSelectionLogRepository {
  /// Append a new hole selection log entry.
  Future<void> append(ManualHoleSelection selection);

  /// Query all selections for a round.
  Future<List<ManualHoleSelection>> queryByRound(String roundId);

  /// Query selections by sync status.
  Future<List<ManualHoleSelection>> queryBySyncStatus(
    ManualHoleSelectionSyncStatus status,
  );

  /// Update sync status for a selection.
  Future<void> updateSyncStatus(
    String id,
    ManualHoleSelectionSyncStatus status,
  );

  /// Count pending sync entries.
  Future<int> countPending();
}

/// SQLite-backed implementation of HoleSelectionLogRepository.
class HoleSelectionLogRepositoryImpl implements HoleSelectionLogRepository {
  final HoleSelectionLogDao _dao;

  HoleSelectionLogRepositoryImpl({HoleSelectionLogDao? dao})
    : _dao = dao ?? HoleSelectionLogDao();

  @override
  Future<void> append(ManualHoleSelection selection) async {
    await _dao.append(selection);
  }

  @override
  Future<List<ManualHoleSelection>> queryByRound(String roundId) async {
    return _dao.queryByRound(roundId);
  }

  @override
  Future<List<ManualHoleSelection>> queryBySyncStatus(
    ManualHoleSelectionSyncStatus status,
  ) async {
    return _dao.queryBySyncStatus(status);
  }

  @override
  Future<void> updateSyncStatus(
    String id,
    ManualHoleSelectionSyncStatus status,
  ) async {
    await _dao.updateSyncStatus(id, status);
  }

  @override
  Future<int> countPending() async {
    return _dao.countPending();
  }
}
