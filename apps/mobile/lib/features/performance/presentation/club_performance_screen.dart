// ClubPerformanceScreen — VSP Mobile App
//
// Per-club performance statistics screen.
// Per Story 11.1 AC-1, AC-2, AC-3 and Slice 3.
//
// Displays:
// - Club name + icon header
// - Sample size badge with label
// - Stats cards: carry avg/median, total avg/median, variability
// - Directional cards: left/right avg±stdDev, short/long avg±stdDev
// - Confidence indicator with explanation text
// - Recommendations locked state with explanation when sample insufficient
// - Navigation to dispersion overlay

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:mobile_theme/mobile_theme.dart';
import '../../../../domain/models/performance/club_performance_stats.dart';
import 'performance_bloc.dart';
import 'performance_event.dart';
import 'performance_state.dart';
import 'widgets/widgets.dart';
import 'dispersion_map_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Screen showing detailed performance statistics for a single club.
class ClubPerformanceScreen extends StatefulWidget {
  final int bagId;
  final int clubId;
  final String clubName;

  const ClubPerformanceScreen({
    super.key,
    required this.bagId,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<ClubPerformanceScreen> createState() => _ClubPerformanceScreenState();
}

class _ClubPerformanceScreenState extends State<ClubPerformanceScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PerformanceBloc>().add(
      LoadClubPerformance(bagId: widget.bagId, clubId: widget.clubId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PerformanceBloc, PerformanceState>(
      builder: (context, state) {
        if (state is ClubPerformanceLoading) {
          return _LoadingScreen(clubName: widget.clubName);
        }

        if (state is PerformanceError && state.lastStats == null) {
          return _ErrorScreen(
            message: context.tr(state.message),
            clubName: widget.clubName,
            onRetry: () {
              context.read<PerformanceBloc>().add(
                LoadClubPerformance(
                  bagId: widget.bagId,
                  clubId: widget.clubId,
                  forceReload: true,
                ),
              );
            },
          );
        }

        if (state is ClubPerformanceLoaded || state is PerformanceError) {
          final stats = state is ClubPerformanceLoaded
              ? state.stats
              : (state as PerformanceError).lastStats!;
          return _ClubPerformanceBody(
            bagId: widget.bagId,
            clubId: widget.clubId,
            clubName: widget.clubName,
            stats: stats,
            isFromCache: state is ClubPerformanceLoaded && state.isFromCache,
          );
        }

        return _LoadingScreen(clubName: widget.clubName);
      },
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _ClubPerformanceBody extends StatelessWidget {
  final int bagId;
  final int clubId;
  final String clubName;
  final ClubPerformanceStats stats;
  final bool isFromCache;

  const _ClubPerformanceBody({
    required this.bagId,
    required this.clubId,
    required this.clubName,
    required this.stats,
    required this.isFromCache,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(clubName),
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
                      'Cached',
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
            LoadClubPerformance(
              bagId: bagId,
              clubId: clubId,
              forceReload: true,
            ),
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
          children: [
            // Recommendations locked banner
            if (stats.recommendationsLocked) ...[
              LockedRecommendationsBanner(
                currentShots: stats.sampleSize,
                requiredShots: 30,
              ),
              const SizedBox(height: 12),
            ],

            // Main stats card
            ClubStatsCard(
              stats: stats,
              onViewDispersion: () => _navigateToDispersion(context),
            ),

            const SizedBox(height: 12),

            // Directional deviation card
            DirectionalStatsCard(stats: stats),

            const SizedBox(height: 12),

            // Confidence badge
            ConfidenceBadge(
              level: stats.confidenceLevel,
              showExplanation: true,
            ),

            const SizedBox(height: VspSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _navigateToDispersion(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<PerformanceBloc>(),
          child: DispersionMapScreen(
            bagId: bagId,
            clubId: clubId,
            clubName: clubName,
          ),
        ),
      ),
    );
  }
}

// ─── Loading Screen ───────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  final String clubName;

  const _LoadingScreen({required this.clubName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(clubName)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

// ─── Error Screen ─────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String message;
  final String clubName;
  final VoidCallback onRetry;

  const _ErrorScreen({
    required this.message,
    required this.clubName,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(clubName)),
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
