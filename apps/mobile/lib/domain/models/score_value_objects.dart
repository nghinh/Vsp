// Score Value Objects — VSP Mobile App
//
// Value types for Score domain model: SyncStatus enum and validation helpers.
//
// Story 5.3 — Slice 1: Domain Models

/// Sync status for score persistence and server synchronization.
///
/// Per architecture §8.3 (local-first):
/// - All writes first persist locally with syncStatus=local
/// - Sync worker retries idempotent API calls when online
/// - Conflict policy: latest client edit wins for scores
enum ScoreSyncStatus {
  /// Score has been saved locally but not yet queued for sync.
  /// This is the initial state when a score is first entered.
  local,

  /// Score is queued in the local event queue, pending sync.
  /// Written when the sync worker has picked up the score event.
  pending,

  /// Score has been confirmed by the server.
  /// Written after successful idempotent API call.
  synced,

  /// Score has a conflict: server has a newer version.
  /// Requires conflict resolution (latest client edit wins per architecture).
  conflict;

  /// Parse from string (SQLite storage or JSON).
  static ScoreSyncStatus fromString(String value) {
    return ScoreSyncStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ScoreSyncStatus.local,
    );
  }

  /// True if this score has been synced to the server.
  bool get isSynced => this == ScoreSyncStatus.synced;

  /// True if this score needs to be synced.
  bool get needsSync =>
      this == ScoreSyncStatus.local || this == ScoreSyncStatus.pending;

  /// Human-readable label for UI.
  String get label {
    switch (this) {
      case ScoreSyncStatus.local:
        return 'Saved locally';
      case ScoreSyncStatus.pending:
        return 'Syncing…';
      case ScoreSyncStatus.synced:
        return 'Synced';
      case ScoreSyncStatus.conflict:
        return 'Conflict';
    }
  }
}

// ─── Score Field Validators ──────────────────────────────────────────────────

/// Validation result for a single score field.
class ScoreFieldValidation {
  final bool isValid;
  final String? errorMessage;

  const ScoreFieldValidation.valid() : isValid = true, errorMessage = null;

  const ScoreFieldValidation.invalid(this.errorMessage) : isValid = false;
}

/// Validates gross score range.
///
/// Rules per slice plan:
/// - null is allowed (hole not yet played)
/// - if set: 1 ≤ grossScore ≤ 30
class GrossScoreValidator {
  static const int minScore = 1;
  static const int maxScore = 30;

  static ScoreFieldValidation validate(int? value) {
    if (value == null) return const ScoreFieldValidation.valid();
    if (value < minScore || value > maxScore) {
      return ScoreFieldValidation.invalid(
        'Gross score must be between $minScore and $maxScore',
      );
    }
    return const ScoreFieldValidation.valid();
  }
}

/// Validates putt count.
///
/// Rules per slice plan:
/// - null is allowed (not yet entered)
/// - if set: 0 ≤ putts ≤ 15
class PuttsValidator {
  static const int minPutts = 0;
  static const int maxPutts = 15;

  static ScoreFieldValidation validate(int? value) {
    if (value == null) return const ScoreFieldValidation.valid();
    if (value < minPutts || value > maxPutts) {
      return ScoreFieldValidation.invalid(
        'Putts must be between $minPutts and $maxPutts',
      );
    }
    return const ScoreFieldValidation.valid();
  }
}

/// Validates penalty stroke count.
///
/// Rules per slice plan:
/// - null is allowed
/// - if set: 0 ≤ penalties ≤ 10
class PenaltiesValidator {
  static const int minPenalties = 0;
  static const int maxPenalties = 10;

  static ScoreFieldValidation validate(int? value) {
    if (value == null) return const ScoreFieldValidation.valid();
    if (value < minPenalties || value > maxPenalties) {
      return ScoreFieldValidation.invalid(
        'Penalties must be between $minPenalties and $maxPenalties',
      );
    }
    return const ScoreFieldValidation.valid();
  }
}

/// Score entry state for progressive disclosure UI.
///
/// Tracks which fields have been entered for a given hole/player.
enum ScoreEntryState {
  /// No score entered yet — only gross score field is visible.
  notStarted,

  /// Gross score entered — primary fields visible.
  grossEntered,

  /// All primary fields entered — full stats visible.
  complete,
}
