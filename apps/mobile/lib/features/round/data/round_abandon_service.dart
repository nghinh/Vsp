// Round Abandon Service — VSP Mobile App
//
// Discards an in-progress round the golfer will not finish.
//
// The round list on the Rounds tab is served by GET /rounds, so the server is
// the only thing that decides whether a round is still "in progress". That is
// why this is deliberately NOT offline-tolerant: nothing drains the round sync
// queue back into the API today, so an abandon that only happened on the
// device would reappear as in-progress on the next refresh. Rather than lie to
// the golfer, a failed call is reported as a failure and the round is left
// alone.
//
// Local bookkeeping (the SQLite round row and the active-round package guard)
// runs only after the server accepted, and is best-effort: it can fail on a
// device with no local round store — e.g. a round started on another install —
// without invalidating the abandon that already succeeded server-side.

import '../../../data/api/round_api.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../core/storage/round_sync_store.dart';
import '../../../domain/models/round.dart';
import '../../../domain/models/round_sync_operation.dart';

/// Outcome of an abandon attempt.
enum RoundAbandonOutcome {
  /// The server marked the round ABANDONED (idempotent — repeats are fine).
  abandoned,

  /// The server could not be reached or refused; nothing changed.
  failed,
}

/// Abandons in-progress rounds.
///
/// Every collaborator is injectable so the flow can be unit-tested without a
/// network or a SQLite database.
class RoundAbandonService {
  final RoundApi _api;
  final RoundSyncStore _syncStore;
  final RoundRepository _localRounds;
  final ActiveRoundGuard _guard;

  RoundAbandonService({
    RoundApi? api,
    RoundSyncStore? syncStore,
    RoundRepository? localRounds,
    ActiveRoundGuard? guard,
  }) : _api = api ?? RoundApi(),
       _syncStore = syncStore ?? RoundSyncStore(),
       _localRounds = localRounds ?? RoundRepository(),
       _guard =
           guard ??
           ActiveRoundGuard(manifestRepo: PackageManifestRepository());

  /// Abandons [round] server-side, then mirrors it locally.
  ///
  /// Returns [RoundAbandonOutcome.failed] without touching local state when the
  /// server call does not succeed.
  Future<RoundAbandonOutcome> abandon(Round round) async {
    try {
      await _api.abandonRound(
        roundId: round.id,
        idempotencyKey: _syncStore.generateIdempotencyKey(
          roundId: round.id,
          operation: RoundSyncOperation.endRound,
        ),
      );
    } catch (_) {
      return RoundAbandonOutcome.failed;
    }

    await _closeLocally(round);
    return RoundAbandonOutcome.abandoned;
  }

  /// Mirrors the abandon in the local round row and releases the package guard
  /// so a new round can start and deferred course updates can be applied.
  Future<void> _closeLocally(Round round) async {
    try {
      final local = await _localRounds.getRound(round.id);
      if (local != null) {
        final now = DateTime.now();
        await _localRounds.updateRound(
          local.copyWith(
            status: RoundStatus.abandoned,
            endedAt: now,
            updatedAt: now,
          ),
        );
      }
      await _guard.recordRoundEnd(round.courseId);
    } catch (_) {
      // No local round store on this device — the server-side abandon stands.
    }
  }
}
