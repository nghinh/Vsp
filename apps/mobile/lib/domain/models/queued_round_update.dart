// Queued Round Update Model — VSP Mobile App
//
// A queued round operation entry for the sync queue.
// Mirrors the QueuedBagUpdate pattern from BagSyncStore.
//
// Story 5.2: Persist Round Locally

import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'round_sync_operation.dart';

/// A queued round operation awaiting sync.
class QueuedRoundUpdate extends Equatable {
  final String idempotencyKey;
  final RoundSyncOperation operation;
  final String roundId;
  final String payload; // JSON
  final DateTime createdAt;
  final DateTime? syncedAt;
  final int retryCount;

  const QueuedRoundUpdate({
    required this.idempotencyKey,
    required this.operation,
    required this.roundId,
    required this.payload,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
  });

  /// True if this entry has been synced.
  bool get isSynced => syncedAt != null;

  /// Parse the payload JSON.
  Map<String, dynamic> get payloadMap =>
      jsonDecode(payload) as Map<String, dynamic>;

  /// Reconstruct from a SQLite row.
  factory QueuedRoundUpdate.fromRow(Map<String, dynamic> row) {
    return QueuedRoundUpdate(
      idempotencyKey: row['idempotency_key'] as String,
      operation: RoundSyncOperation.values.firstWhere(
        (e) => e.name == row['operation'],
        orElse: () => RoundSyncOperation.startRound,
      ),
      roundId: row['round_id'] as String,
      payload: row['payload'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      syncedAt: row['synced_at'] != null
          ? DateTime.parse(row['synced_at'] as String)
          : null,
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    idempotencyKey,
    operation,
    roundId,
    payload,
    createdAt,
    syncedAt,
    retryCount,
  ];
}
