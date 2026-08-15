// RoundSummaryScreen — VSP Mobile App
//
// Main screen displaying round completion summary with per-player scorecard,
// stats, and sync state.
// Per Story 5.5 Slice 3: AC-2 summary display with per-player scorecard, stats, sync state.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/round_sync_store.dart';
import '../../../data/repositories/hole_score_repository.dart';
import '../../../data/repositories/package_manifest_repository.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/services/active_round_guard.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../data/services/round_state_service.dart';
import '../domain/round_summary.dart';
import '../domain/score_entry.dart';
import '../domain/sync_state.dart';
import 'round_completion_bloc.dart';
import 'widgets/round_stats_card.dart';
import 'widgets/score_row_widget.dart';
import 'widgets/sync_state_badge.dart';
import 'widgets/correction_dialog.dart';
import 'widgets/round_recap_card.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Main round summary screen.
///
/// This screen and its bloc were complete and reachable from nowhere: finishing
/// a round ended in `popUntil((route) => route.isFirst)`, so eighteen holes of
/// scoring dropped the golfer on the home screen with a toast. It would also
/// have thrown if anything had pushed it, because it resolved five
/// dependencies with `context.read()` and the app provided none of them — the
/// only RepositoryProviders in the tree are the hole map, corrections and
/// location.
///
/// It now builds its own dependencies, so any caller can push it. They are all
/// on-device stores; the one asynchronous piece is [SharedPreferences], which
/// [ConnectivityService] needs to answer the Wi-Fi-only question.
class RoundSummaryScreen extends StatefulWidget {
  final String roundId;

  /// Injectable for tests, which have neither SQLite nor SharedPreferences.
  final RoundCompletionBloc? bloc;

  const RoundSummaryScreen({super.key, required this.roundId, this.bloc});

  @override
  State<RoundSummaryScreen> createState() => _RoundSummaryScreenState();
}

class _RoundSummaryScreenState extends State<RoundSummaryScreen> {
  /// Built once. A future created in `build` would be recreated on every
  /// rebuild, reopening the database behind the screen.
  late final Future<RoundCompletionBloc> _bloc = _createBloc();

  /// The bloc once built, so [dispose] can close what this screen created.
  ///
  /// Null while it is still being built, and left null for an injected one —
  /// whoever injected it owns its lifetime.
  RoundCompletionBloc? _owned;

  Future<RoundCompletionBloc> _createBloc() async {
    final injected = widget.bloc;
    if (injected != null) {
      injected.add(LoadRoundSummary(roundId: widget.roundId));
      return injected;
    }

    final roundRepo = RoundRepository();
    final syncStore = RoundSyncStore();
    final activeRoundGuard = ActiveRoundGuard(
      manifestRepo: PackageManifestRepository(),
    );

    final bloc = RoundCompletionBloc(
      roundRepo: roundRepo,
      roundStateService: RoundStateService(
        roundRepo: roundRepo,
        scoreRepo: HoleScoreRepository(),
        playerRepo: PlayerRepository(),
        syncStore: syncStore,
        activeRoundGuard: activeRoundGuard,
      ),
      syncStore: syncStore,
      activeRoundGuard: activeRoundGuard,
      connectivityService: ConnectivityService(
        prefs: await SharedPreferences.getInstance(),
      ),
    );
    // The screen may already be gone by the time the preferences resolve.
    if (!mounted) {
      await bloc.close();
      return bloc;
    }
    _owned = bloc;
    bloc.add(LoadRoundSummary(roundId: widget.roundId));
    return bloc;
  }

  @override
  void dispose() {
    _owned?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RoundCompletionBloc>(
      future: _bloc,
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context);

        if (snapshot.hasError) {
          // The round is already finished and already recorded by the time
          // this screen opens, so a summary that cannot be assembled is a
          // missing view of a saved round — not a lost round. Say that.
          return Scaffold(
            appBar: AppBar(title: Text(l10n.summaryTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.summaryUnavailable,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final bloc = snapshot.data;
        if (bloc == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.summaryTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // .value, not create: the bloc is built and loaded above, and this
        // screen closes what it built in dispose.
        return BlocProvider.value(
          value: bloc,
          child: const _RoundSummaryView(),
        );
      },
    );
  }
}

class _RoundSummaryView extends StatelessWidget {
  const _RoundSummaryView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoundCompletionBloc, RoundCompletionState>(
      builder: (context, state) {
        if (state is RoundSummaryLoading) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context).summaryTitle),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is RoundCompletionError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context).summaryTitle),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(context.tr(state.message)),
                ],
              ),
            ),
          );
        }

        // Every state that carries a card renders the card. The two
        // correction states were missing, so submitting a correction dropped
        // the golfer onto the bare "loading" fallback below and left them
        // there — the card was in the state all along, unrendered.
        final summary = switch (state) {
          RoundSummaryLoaded(:final summary) => summary,
          RoundCompletionSuccess(:final summary) => summary,
          RoundCompletionOffline(:final summary) => summary,
          RoundCorrectionSuccess(:final summary) => summary,
          RoundCorrectionFailure(:final summary) => summary,
          _ => null,
        };
        if (summary != null) {
          return _SummaryScaffold(summary: summary);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).summaryTitle),
          ),
          body: Center(child: Text(AppLocalizations.of(context).commonLoading)),
        );
      },
    );
  }
}

class _SummaryScaffold extends StatelessWidget {
  final RoundSummary summary;

  const _SummaryScaffold({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).summaryComplete),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SyncStateBadge(syncState: summary.overallSyncState),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.courseName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(summary.startedAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sync state indicator
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SyncStateBanner(state: summary.overallSyncState),
              ),
            ),

            // The Zalo message, written by the server from these same rows.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: RoundRecapCard(
                  roundId: summary.roundId,
                  subject: summary.courseName,
                ),
              ),
            ),

            // Stats card
            if (summary.players.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RoundStatsCard(
                    fairwaysHit: summary.players.first.fairwaysHit,
                    par4Or5Count: summary.players.first.par4Or5Count,
                    girCount: summary.players.first.girCount,
                    totalHoles: summary.players.first.holes.length,
                    totalPutts: summary.players.first.totalPutts,
                    totalPenalties: summary.players.first.totalPenalties,
                  ),
                ),
              ),

            // Per-player scorecards
            for (final player in summary.players) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _PlayerCardHeader(player: player),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final hole = player.holes[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ScoreRowWidget(
                      entry: hole,
                      onTap: () => _showCorrectionDialog(context, player, hole),
                    ),
                  );
                }, childCount: player.holes.length),
              ),
            ],

            // Empty state if no players
            if (summary.players.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.golf_course,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).summaryNoScores,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).summaryNoScoresSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _BottomActions(summary: summary),
    );
  }

  /// Corrects one hole on one player's card.
  ///
  /// The player used to be `summary.players.first` regardless of whose row was
  /// tapped, so in a flight of four every correction was filed against the
  /// first golfer — including corrections to somebody else's hole.
  void _showCorrectionDialog(
    BuildContext context,
    PlayerScoreSummary player,
    ScoreEntry hole,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => CorrectionDialog(
        playerId: player.playerId,
        holes: [hole],
        onSubmit: (request) {
          context.read<RoundCompletionBloc>().add(
            SubmitCorrection(roundId: summary.roundId, request: request),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _PlayerCardHeader extends StatelessWidget {
  final PlayerScoreSummary player;

  const _PlayerCardHeader({required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          player.playerName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '${player.totalStrokes}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: _relativeColor(player.relativeScore),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          player.relativeScore >= 0
              ? '+${player.relativeScore}'
              : '${player.relativeScore}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _relativeColor(player.relativeScore),
          ),
        ),
      ],
    );
  }

  Color _relativeColor(int relativeScore) {
    if (relativeScore < 0) return Colors.green;
    if (relativeScore > 0) return Colors.red;
    return Colors.grey;
  }
}

class _SyncStateBanner extends StatelessWidget {
  final SyncState state;

  const _SyncStateBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (color, icon, message) = switch (state) {
      SyncState.synced => (
        Colors.green,
        Icons.check_circle,
        AppLocalizations.of(context).summarySynced,
      ),
      SyncState.pending => (
        Colors.amber,
        Icons.cloud_upload,
        AppLocalizations.of(context).summaryOffline,
      ),
      SyncState.syncing => (
        Colors.blue,
        Icons.sync,
        AppLocalizations.of(context).summarySyncing,
      ),
      SyncState.failed => (
        Colors.red,
        Icons.error,
        AppLocalizations.of(context).summarySyncFailed,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final RoundSummary summary;

  const _BottomActions({required this.summary});

  /// Opens the correction dialog over every hole on the card.
  ///
  /// Tapping a single row already opens this dialog for that hole; this is the
  /// same flow with the whole round to choose from, so a correction made here
  /// travels the route that was already built and tested for it.
  void _editScores(BuildContext context) {
    final player = summary.players.first;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => CorrectionDialog(
        playerId: player.playerId,
        holes: player.holes,
        onSubmit: (request) {
          context.read<RoundCompletionBloc>().add(
            SubmitCorrection(roundId: summary.roundId, request: request),
          );
        },
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await SharePlus.instance.share(
      ShareParams(text: _shareText(l10n), subject: summary.courseName),
    );
  }

  /// The card as text: course, date, and each player's total against par.
  ///
  /// Text rather than a rendered image — it pastes into Zalo, Messenger and
  /// SMS alike, and it says nothing the golfer did not already see on screen.
  String _shareText(AppLocalizations l10n) {
    final date = summary.endedAt ?? summary.startedAt;
    final lines = <String>[
      summary.courseName,
      '${date.day}/${date.month}/${date.year}',
      '',
    ];
    for (final player in summary.players) {
      final relative = player.totalPar == 0
          ? ''
          : player.relativeScore == 0
          ? ' (E)'
          : player.relativeScore > 0
          ? ' (+${player.relativeScore})'
          : ' (${player.relativeScore})';
      lines.add(
        '${player.playerName}: ${player.totalStrokes}$relative — '
        '${player.holes.length} ${l10n.summaryHolesLabel}',
      );
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                // Both of these were `onPressed: () {}` with a comment where
                // the action should have been, so they looked live and did
                // nothing. A hole is corrected through the same dialog the
                // scorecard rows use, which is already wired to the
                // correction flow — there is no second editor to reach.
                onPressed: summary.players.isEmpty
                    ? null
                    : () => _editScores(context),
                icon: const Icon(Icons.edit),
                label: Text(AppLocalizations.of(context).summaryEditScores),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: summary.players.isEmpty
                    ? null
                    : () => _share(context),
                icon: const Icon(Icons.share),
                label: Text(AppLocalizations.of(context).summaryShare),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check),
                label: Text(AppLocalizations.of(context).commonDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
