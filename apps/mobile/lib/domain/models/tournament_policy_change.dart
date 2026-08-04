// TournamentPolicyChange — Audit record for TournamentPolicy changes
// VSP Mobile App
//
// Tracks every policy creation and modification with before/after snapshots
// for compliance and auditability.
//
// Per PRD §8.12: "Enabled feature set is auditable."
//
// Story 7.4 — Slice A: TournamentPolicy Domain Model

import 'package:equatable/equatable.dart';

/// Audit record capturing a single change to a [TournamentPolicy].
///
/// Emitted on every create, update, and lock operation so that
/// tournament directors can review the full history of a policy.
class TournamentPolicyChange extends Equatable {
  /// Unique identifier for this audit record.
  final String id;

  /// ID of the policy that was changed.
  final String policyId;

  /// ID of the actor who made the change (user ID or 'system').
  final String changedBy;

  /// Timestamp when the change was made.
  final DateTime changedAt;

  /// JSON snapshot of the policy before this change.
  ///
  /// Null for policy creation events.
  final Map<String, dynamic>? beforeJson;

  /// JSON snapshot of the policy after this change.
  final Map<String, dynamic> afterJson;

  /// Optional reason for the change (e.g., "Round started", "Director update").
  final String? reason;

  const TournamentPolicyChange({
    required this.id,
    required this.policyId,
    required this.changedBy,
    required this.changedAt,
    this.beforeJson,
    required this.afterJson,
    this.reason,
  });

  /// Returns true if this is a creation event (no before state).
  bool get isCreation => beforeJson == null;

  /// Returns true if this is a lock event.
  bool get isLockEvent =>
      beforeJson != null &&
      afterJson['isLocked'] == true &&
      (beforeJson!['isLocked'] as bool? ?? false) == false;

  // ─── JSON ─────────────────────────────────────────────────────────────────

  factory TournamentPolicyChange.fromJson(Map<String, dynamic> json) {
    return TournamentPolicyChange(
      id: json['id'] as String,
      policyId: json['policyId'] as String,
      changedBy: json['changedBy'] as String,
      changedAt: DateTime.parse(json['changedAt'] as String),
      beforeJson: json['beforeJson'] as Map<String, dynamic>?,
      afterJson: json['afterJson'] as Map<String, dynamic>,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'policyId': policyId,
    'changedBy': changedBy,
    'changedAt': changedAt.toIso8601String(),
    if (beforeJson != null) 'beforeJson': beforeJson,
    'afterJson': afterJson,
    if (reason != null) 'reason': reason,
  };

  @override
  List<Object?> get props => [
    id,
    policyId,
    changedBy,
    changedAt,
    beforeJson,
    afterJson,
    reason,
  ];
}
