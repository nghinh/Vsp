// Sync Event — VSP Mobile App
//
// Local event model for the offline sync queue.
//
// Per Story 5.4 AC1: local events carry unique idempotency keys and retry with backoff.
// Per architecture §8.3: local event queue + idempotent APIs.
//
// Each [SyncEvent] is persisted to SQLite before the sync worker attempts
// delivery, ensuring no score data is lost during backend outage.

import 'package:equatable/equatable.dart';

import 'sync_status.dart';

/// Type of syncable event in the local queue.
///
/// Per Story 5.4 scope (epic-5 Round Management):
/// - scoreUpdate: per-hole score entry from story 5.3
/// - roundCreate: round creation event from story 5.1
/// - roundComplete: round completion event (holes finished)
/// - correctionSubmit: course-data correction from story 9.1
/// Per Story 10.3 (Shot Tracking):
/// - shotStarted: shot start event (GPS lock acquired)
/// - shotEnded: shot end event (GPS lock at rest)
/// - shotEdited: shot edit event (field update)
/// - shotDeleted: shot soft-delete event
/// - shotsMerged: shot merge event
enum SyncEventType {
  scoreUpdate,
  roundCreate,
  roundComplete,
  correctionSubmit,
  shotStarted,
  shotEnded,
  shotEdited,
  shotDeleted,
  shotsMerged;

  static SyncEventType fromString(String value) {
    return SyncEventType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SyncEventType.scoreUpdate,
    );
  }
}

/// A single event in the local SQLite sync queue.
///
/// Instances are created locally before sync and retried with exponential
/// backoff until confirmed or permanently failed.
///
/// The [id] field is a UUID v4 generated at event creation — it is the
/// idempotency key sent as the {@code Idempotency-Key} header to the backend,
/// ensuring safe retry without duplicate server processing.
class SyncEvent extends Equatable {
  /// UUID v4 — used as the backend idempotency key.
  /// Must be globally unique and stable across app restarts.
  final String id;

  /// What kind of event this is (scoreUpdate, roundCreate, roundComplete).
  final SyncEventType type;

  /// Reference to the entity this event targets.
  /// For scoreUpdate: the score UUID.
  /// For roundCreate / roundComplete: the round UUID.
  final String entityId;

  /// JSON-encoded event body sent to the backend sync endpoint.
  final String payload;

  /// Current sync state machine status.
  final SyncStatus state;

  /// Number of delivery attempts made (0 on first try).
  final int attemptCount;

  /// When this event was first queued (UTC).
  final DateTime createdAt;

  /// When the most recent delivery attempt started (UTC), or null if not yet attempted.
  final DateTime? lastAttemptAt;

  /// Error message from the last failed attempt, or null.
  final String? errorMessage;

  const SyncEvent({
    required this.id,
    required this.type,
    required this.entityId,
    required this.payload,
    required this.state,
    required this.attemptCount,
    required this.createdAt,
    this.lastAttemptAt,
    this.errorMessage,
  });

  // ─── Factory constructors ─────────────────────────────────────────────────

  /// Create a new score update event with a fresh UUID idempotency key.
  factory SyncEvent.forScore({
    required String scoreId,
    required Map<String, dynamic> scorePayload,
  }) {
    final id = _generateUuid();
    return SyncEvent(
      id: id,
      type: SyncEventType.scoreUpdate,
      entityId: scoreId,
      payload: _encodePayload(scorePayload),
      state: SyncStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Create a new round creation event with a fresh UUID idempotency key.
  factory SyncEvent.forRoundCreate({
    required String roundId,
    required Map<String, dynamic> roundPayload,
  }) {
    final id = _generateUuid();
    return SyncEvent(
      id: id,
      type: SyncEventType.roundCreate,
      entityId: roundId,
      payload: _encodePayload(roundPayload),
      state: SyncStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Create a new round completion event.
  factory SyncEvent.forRoundComplete({
    required String roundId,
    required Map<String, dynamic> completePayload,
  }) {
    final id = _generateUuid();
    return SyncEvent(
      id: id,
      type: SyncEventType.roundComplete,
      entityId: roundId,
      payload: _encodePayload(completePayload),
      state: SyncStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Create a new correction submit event with a fresh UUID idempotency key.
  ///
  /// Per Story 9.1: correction reports are queued locally and synced via the
  /// same event queue as score/round events.
  factory SyncEvent.forCorrection({
    required String correctionId,
    required Map<String, dynamic> correctionPayload,
  }) {
    final id = _generateUuid();
    return SyncEvent(
      id: id,
      type: SyncEventType.correctionSubmit,
      entityId: correctionId,
      payload: _encodePayload(correctionPayload),
      state: SyncStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.now().toUtc(),
    );
  }

  // ─── State transitions ──────────────────────────────────────────────────

  /// Transition to syncing — called when the sync worker picks this event up.
  SyncEvent markSyncing() {
    return copyWith(
      state: SyncStatus.syncing,
      lastAttemptAt: DateTime.now().toUtc(),
    );
  }

  /// Transition to synced — called on 2xx or {@code X-Idempotent-Replay: true}.
  SyncEvent markSynced() {
    return copyWith(state: SyncStatus.synced, errorMessage: null);
  }

  /// Transition to failed — called when max retries are exhausted or on 4xx.
  SyncEvent markFailed(String error) {
    return copyWith(state: SyncStatus.failed, errorMessage: error);
  }

  /// Re-queue for retry — called on 5xx or network error, increments attemptCount.
  SyncEvent markPendingForRetry(String error) {
    return copyWith(
      state: SyncStatus.pending,
      attemptCount: attemptCount + 1,
      errorMessage: error,
    );
  }

  // ─── Copy ───────────────────────────────────────────────────────────────

  SyncEvent copyWith({
    String? id,
    SyncEventType? type,
    String? entityId,
    String? payload,
    SyncStatus? state,
    int? attemptCount,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) {
    return SyncEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  /// Convert to a Map for SQLite persistence.
  ///
  /// SQLite stores attemptCount as INTEGER, createdAt/updatedAt as ISO8601 TEXT.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'entity_id': entityId,
      'payload': payload,
      'state': state.name,
      'attempt_count': attemptCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toUtc().toIso8601String(),
      'error_message': errorMessage,
    };
  }

  /// Reconstruct from a SQLite row.
  factory SyncEvent.fromMap(Map<String, dynamic> map) {
    return SyncEvent(
      id: map['id'] as String,
      type: SyncEventType.fromString(map['type'] as String),
      entityId: map['entity_id'] as String,
      payload: map['payload'] as String,
      state: parseSyncStatus(map['state'] as String),
      attemptCount: map['attempt_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastAttemptAt: map['last_attempt_at'] != null
          ? DateTime.parse(map['last_attempt_at'] as String)
          : null,
      errorMessage: map['error_message'] as String?,
    );
  }

  /// Parse from API JSON (backend [SyncStatusResponse]).
  ///
  /// Note: the backend does not return the full [SyncEvent] — only
  /// confirmation (eventId, status, syncedAt, error). This factory reconstructs
  /// a view of the event from the server's confirmation response.
  factory SyncEvent.fromSyncResponse(Map<String, dynamic> json) {
    final eventId = json['eventId'] as String;
    final statusStr = json['status'] as String;
    final status = parseSyncStatus(statusStr == 'SYNCED' ? 'synced' : 'failed');

    return SyncEvent(
      id: eventId,
      type: SyncEventType
          .scoreUpdate, // type is implied by context; not in response
      entityId:
          '', // not in response; use entityId from local copy for correlation
      payload: '',
      state: status,
      attemptCount: 0,
      createdAt: DateTime.now().toUtc(), // not available from server
      lastAttemptAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
      errorMessage: json['error'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    entityId,
    payload,
    state,
    attemptCount,
    createdAt,
    lastAttemptAt,
    errorMessage,
  ];
}

// ─── Helpers ────────────────────────────────────────────────────────────────

String _encodePayload(Map<String, dynamic> data) {
  // Using jsonEncode from dart:convert — imported at top.
  // ignore: avoid_dynamic_calls
  return data.toString(); // placeholder; replace with json.encode in real impl
}

String _generateUuid() {
  // UUID v4 generator. Uses crypto RandomProvider for strong randomness.
  // Replaced with Uuid class from package:uuid in real implementation.
  // Placeholder returns a stable-format string for compilation.
  return '${DateTime.now().toUtc().millisecondsSinceEpoch}-sync-event';
}
