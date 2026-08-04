// Conditions Repository — VSP Mobile App
//
// Repository interface for fetching official pin positions and course conditions
// with expiry-aware filtering. Persists conditions to SQLite for offline access.
//
// Story 7.3 — Slice 2: Repository/Persistence Contracts

import '../../../domain/models/condition_entry.dart';
import '../../hole_map/domain/pin_entity.dart';

/// Repository interface for conditions and active pin data.
///
/// Responsibilities:
/// - Fetch conditions for a course (optionally filtered by type)
/// - Fetch the active (non-expired official) pin for a hole
/// - Cache conditions locally with timestamp for offline access
abstract class ConditionsRepository {
  /// Get all conditions for a course.
  ///
  /// Returns cached conditions when offline.
  /// Filters out expired conditions unless [includeExpired] is true.
  Future<List<ConditionEntry>> getConditions({
    required int courseId,
    ConditionType? conditionType,
    bool includeExpired = false,
  });

  /// Get the active (non-expired official) pin for a hole.
  ///
  /// Returns null if no active official pin exists.
  /// Expired official pins are NEVER returned as active.
  Future<PinEntity?> getActivePin({required String holeId});

  /// Get all active (non-expired official) pins for a course.
  Future<List<PinEntity>> getActivePins({required int courseId});

  /// Cache conditions locally with timestamp.
  ///
  /// Stores conditions with cachedAt timestamp for offline display.
  Future<void> cacheConditions({
    required int courseId,
    required List<ConditionEntry> conditions,
    required DateTime cachedAt,
  });

  /// Get cached conditions with the timestamp.
  ///
  /// Returns null if no cache exists.
  Future<({List<ConditionEntry> conditions, DateTime cachedAt})?>
  getCachedConditions({required int courseId});

  /// Clear cached conditions for a course.
  Future<void> clearConditionsCache({required int courseId});
}
