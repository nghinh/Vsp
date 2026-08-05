// RoundSummaryScreen — VSP Mobile App
//
// Main screen displaying round completion summary with per-player scorecard,
// stats, and sync state.
// Per Story 5.5 Slice 3: AC-2 summary display with per-player scorecard, stats, sync state.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/round_summary.dart';
import '../domain/score_entry.dart';
import '../domain/sync_state.dart';
import 'round_completion_bloc.dart';
import 'widgets/round_stats_card.dart';
import 'widgets/score_row_widget.dart';
import 'widgets/sync_state_badge.dart';
import 'widgets/correction_dialog.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Main round summary screen.
class RoundSummaryScreen extends StatelessWidget {
  final String roundId;

  const RoundSummaryScreen({super.key, required this.roundId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RoundCompletionBloc(
        roundRepo: context.read(),
        roundStateService: context.read(),
        syncStore: context.read(),
        activeRoundGuard: context.read(),
        connectivityService: context.read(),
      )..add(LoadRoundSummary(roundId: roundId)),
      child: const _RoundSummaryView(),
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
            appBar: AppBar(title: Text(AppLocalizations.of(context).summaryTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is RoundCompletionError) {
          return Scaffold(
            appBar: AppBar(title: Text(AppLocalizations.of(context).summaryTitle)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                ],
              ),
            ),
          );
        }

        if (state is RoundSummaryLoaded ||
            state is RoundCompletionSuccess ||
            state is RoundCompletionOffline) {
          final summary = state is RoundSummaryLoaded
              ? state.summary
              : state is RoundCompletionSuccess
              ? state.summary
              : (state as RoundCompletionOffline).summary;

          return _SummaryScaffold(summary: summary);
        }

        return Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.of(context).summaryTitle)),
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
                      onTap: () => _showCorrectionDialog(context, hole),
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

  void _showCorrectionDialog(BuildContext context, ScoreEntry hole) {
    showDialog(
      context: context,
      builder: (dialogContext) => CorrectionDialog(
        playerId: summary.players.isNotEmpty
            ? summary.players.first.playerId
            : '',
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
      SyncState.syncing => (Colors.blue, Icons.sync, AppLocalizations.of(context).summarySyncing),
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
                onPressed: () {
                  // Edit scores action
                },
                icon: const Icon(Icons.edit),
                label: Text(AppLocalizations.of(context).summaryEditScores),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Share action
                },
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
