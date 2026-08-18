// BagPerformanceScreen — VSP Mobile App
//
// Bag-level performance screen showing all clubs with performance summaries.
// Per Story 11.1 AC-1, AC-2, AC-3 and Slice 3.
//
// Displays:
// - List of clubs with mini performance cards
// - Tap to navigate to ClubPerformanceScreen

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile_theme/mobile_theme.dart';
import '../../../../domain/models/performance/club_performance_stats.dart';
import '../../bag/data/bag_dto.dart';
import 'performance_bloc.dart';
import 'performance_event.dart';
import 'performance_state.dart';
import 'widgets/widgets.dart';
import 'club_performance_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Screen showing performance summary for all clubs in a bag.
class BagPerformanceScreen extends StatefulWidget {
  final int bagId;
  final List<BagDTO> bags;

  const BagPerformanceScreen({
    super.key,
    required this.bagId,
    required this.bags,
  });

  @override
  State<BagPerformanceScreen> createState() => _BagPerformanceScreenState();
}

class _BagPerformanceScreenState extends State<BagPerformanceScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PerformanceBloc>().add(
      LoadBagPerformance(bagId: widget.bagId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PerformanceBloc, PerformanceState>(
      builder: (context, state) {
        if (state is BagPerformanceLoading) {
          return const _LoadingScreen();
        }

        if (state is PerformanceError && state.lastPerformance == null) {
          return _ErrorScreen(
            message: context.tr(state.message),
            onRetry: () {
              context.read<PerformanceBloc>().add(
                LoadBagPerformance(bagId: widget.bagId, forceReload: true),
              );
            },
          );
        }

        if (state is BagPerformanceLoaded || state is PerformanceError) {
          final performance = state is BagPerformanceLoaded
              ? state.performance
              : (state as PerformanceError).lastPerformance!;
          return _BagPerformanceBody(
            bagId: widget.bagId,
            performance: performance,
            bags: widget.bags,
            isFromCache: state is BagPerformanceLoaded && state.isFromCache,
          );
        }

        return const _LoadingScreen();
      },
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _BagPerformanceBody extends StatelessWidget {
  final int bagId;
  final BagPerformance performance;
  final List<BagDTO> bags;
  final bool isFromCache;

  const _BagPerformanceBody({
    required this.bagId,
    required this.performance,
    required this.bags,
    required this.isFromCache,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bag = bags.firstWhere((b) => b.id == bagId, orElse: () => bags.first);

    return Scaffold(
      appBar: AppBar(
        title: Text('${bag.name} Performance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isFromCache)
            Tooltip(
              message: AppLocalizations.of(context).performanceCachedData,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.offline_bolt,
                      size: 14,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context).commonCached,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<PerformanceBloc>().add(
            LoadBagPerformance(bagId: bagId, forceReload: true),
          );
        },
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final bag = bags.firstWhere((b) => b.id == bagId, orElse: () => bags.first);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (performance.clubs.isEmpty) {
      return _EmptyState(bagName: bag.name);
    }

    return ListView(
      padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
      children: [
        // Summary header
        _SummaryHeader(performance: performance),

        const SizedBox(height: VspSpacing.md),

        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: VspSpacing.xs),
          child: Text(
            AppLocalizations.of(context).clubPerformanceHeading,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: VspLetterSpacing.wide,
            ),
          ),
        ),

        const SizedBox(height: VspSpacing.sm),

        // Club performance list
        ...performance.clubs.map<Widget>((club) {
          // Find club name from bag's clubs
          ClubDTO? clubDTO;
          for (final candidate in bag.clubs) {
            if (candidate.id == club.clubId) {
              clubDTO = candidate;
              break;
            }
          }
          final clubName =
              clubDTO?.clubType.displayName ?? 'Club ${club.clubId}';

          return Padding(
            padding: const EdgeInsets.only(bottom: VspSpacing.sm),
            child: ClubPerformanceMiniCard(
              stats: club,
              clubName: clubName,
              onTap: () => _navigateToClubPerformance(context, club, clubName),
            ),
          );
        }),

        const SizedBox(height: VspSpacing.xl),
      ],
    );
  }

  void _navigateToClubPerformance(
    BuildContext context,
    ClubPerformanceStats club,
    String clubName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<PerformanceBloc>(),
          child: ClubPerformanceScreen(
            bagId: bagId,
            clubId: club.clubId,
            clubName: clubName,
          ),
        ),
      ),
    );
  }
}

// ─── Summary Header ────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final BagPerformance performance;

  const _SummaryHeader({required this.performance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalClubs = performance.clubs.length;
    final robustCount = performance.clubs
        .where((c) => c.sampleSizeLabel.name == 'robust')
        .length;
    final totalShots = performance.clubs.fold<int>(
      0,
      (sum, c) => sum + c.sampleSize as int,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).bagSummaryHeading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryItem(
                label: AppLocalizations.of(context).analyticsClubs,
                value: totalClubs.toString(),
                icon: Icons.golf_course,
              ),
              const SizedBox(width: 24),
              _SummaryItem(
                label: AppLocalizations.of(context).performanceRobust,
                value: robustCount.toString(),
                icon: Icons.verified,
              ),
              const SizedBox(width: 24),
              _SummaryItem(
                label: AppLocalizations.of(context).analyticsTotalShots,
                value: totalShots.toString(),
                icon: Icons.scatter_plot,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String bagName;

  const _EmptyState({required this.bagName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: VspSpacing.md),
            Text(AppLocalizations.of(context).performanceNoData, style: theme.textTheme.titleMedium),
            const SizedBox(height: VspSpacing.sm),
            Text(
              'Start recording shots with your clubs to see performance statistics.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading Screen ───────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).performanceBagTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

// ─── Error Screen ─────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).performanceBagTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: VspSpacing.md),
              Text(
                AppLocalizations.of(context).performanceLoadFailedTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: VspSpacing.sm),
              Text(
                // tr: server text passes through; a message key turns
                // Vietnamese instead of leaking English onto the screen.
                context.tr(message),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VspSpacing.lg),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).commonTryAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
