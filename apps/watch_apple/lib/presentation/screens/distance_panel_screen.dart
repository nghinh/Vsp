// Distance Panel Screen — VSP Watch Apple App
//
// Primary glanceable screen showing hole info and distance panel.
// AC-1: Watch displays hole number, par, current score.
// AC-2: Watch displays front-center-back distances to green.
// AC-3: Watch displays pin position and hazard distances.
// AC-4: Watch provides navigation between holes.
//
// Story 10.1 — Slice 2: Watch UI Shell & Navigation

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/hole_info_badge.dart';
import '../widgets/distance_display.dart';
import '../../domain/watch_distance_data.dart';
import '../../domain/watch_round_session.dart';
import '../theme/watch_theme.dart';

/// Distance panel screen — primary watch UI for on-course use.
///
/// This is the main glanceable screen that golfers see during play.
/// It shows:
/// - Current hole number and par
/// - Front-center-back distances
/// - Pin/target distance
/// - Hazard distances (if any)
/// - GPS quality indicator
/// - Navigation buttons (prev hole, score entry, next hole)
///
/// Two-tap flow:
/// 1. Tap distance panel → expands to show more detail (future)
/// 2. Tap "SCORE" button → navigate to score entry
class DistancePanelScreen extends StatelessWidget {
  final WatchRoundSession? session;
  final WatchDistanceData? distanceData;
  final String? selectedPlayerId;
  final VoidCallback? onPreviousHole;
  final VoidCallback? onNextHole;
  final VoidCallback? onScoreEntry;
  final VoidCallback? onMainMenu;

  const DistancePanelScreen({
    super.key,
    this.session,
    this.distanceData,
    this.selectedPlayerId,
    this.onPreviousHole,
    this.onNextHole,
    this.onScoreEntry,
    this.onMainMenu,
  });

  bool get _canGoBack => (session?.currentHole ?? 1) > 1;
  bool get _canGoForward => (session?.currentHole ?? 18) < (session?.totalHoles ?? 18);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: WatchColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WatchSpacing.screenPadding),
          child: Column(
            children: [
              // Top row: Hole info + GPS badge
              _buildTopRow(),

              const SizedBox(height: WatchSpacing.sectionGap),

              // Distance panel (main content)
              Expanded(
                child: _buildDistancePanel(),
              ),

              const SizedBox(height: WatchSpacing.sectionGap),

              // Bottom: Navigation buttons
              _buildNavigationRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    final hole = session?.currentHole ?? 1;
    final par = session?.currentPar ?? 4;
    final gpsQuality = session?.gpsQuality.name ?? 'unknown';
    final gpsAccuracy = session?.gpsAccuracyMeters;
    final syncStatus = session?.syncStatus ?? 'local';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        HoleInfoBadge(
          holeNumber: hole,
          par: par,
          totalHoles: session?.totalHoles ?? 18,
        ),
        GpsQualityBadge(
          quality: gpsQuality,
          accuracyMeters: gpsAccuracy,
        ),
      ],
    );
  }

  Widget _buildDistancePanel() {
    // If no distance data, show placeholder
    if (distanceData == null) {
      return _DistancePlaceholder();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Score summary (if player selected)
        if (selectedPlayerId != null) ...[
          _ScoreSummary(
            session: session,
            playerId: selectedPlayerId!,
          ),
          const SizedBox(height: WatchSpacing.elementGap),
        ],

        // Main distance display
        DistanceDisplay(
          distanceData: distanceData!,
          showPin: true,
          showConfidence: true,
        ),

        // Hazards (if any)
        if (distanceData!.hazards.isNotEmpty) ...[
          const SizedBox(height: WatchSpacing.elementGap),
          HazardDistanceList(
            hazards: distanceData!.hazards,
            useYards: false, // TODO: respect user preference
          ),
        ],

        // Sync status
        const SizedBox(height: WatchSpacing.tightGap),
        SyncStatusBadge(syncStatus: syncStatus),
      ],
    );
  }

  Widget _buildNavigationRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous hole
        _NavButton(
          icon: CupertinoIcons.chevron_left,
          label: 'PREV',
          onTap: _canGoBack ? onPreviousHole : null,
        ),

        // Score entry (primary action)
        _NavButton(
          icon: CupertinoIcons.pencil,
          label: 'SCORE',
          onTap: onScoreEntry,
          isPrimary: true,
        ),

        // Next hole
        _NavButton(
          icon: CupertinoIcons.chevron_right,
          label: 'NEXT',
          onTap: _canGoForward ? onNextHole : null,
        ),
      ],
    );
  }
}

/// Placeholder when no distance data is available.
class _DistancePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.location_slash,
            size: 32,
            color: WatchColors.onBackgroundTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            'No GPS Signal',
            style: WatchTypography.holeInfo.copyWith(
              color: WatchColors.onBackgroundSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Move to get fix',
            style: WatchTypography.caption,
          ),
        ],
      ),
    );
  }
}

/// Score summary showing current player total.
class _ScoreSummary extends StatelessWidget {
  final WatchRoundSession? session;
  final String playerId;

  const _ScoreSummary({
    required this.session,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context) {
    if (session == null) return const SizedBox.shrink();

    final totalStrokes = session!.totalStrokesFor(playerId);
    final currentHoleStrokes = session!.scores
        .where((s) => s.playerId == playerId && s.holeNumber == session!.currentHole)
        .firstOrNull
        ?.strokes;

    return Semantics(
      label: 'Current score: $totalStrokes strokes${currentHoleStrokes != null ? ', $currentHoleStrokes on this hole' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: WatchColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TOTAL',
              style: WatchTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$totalStrokes',
              style: WatchTypography.holeInfo.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (currentHoleStrokes != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: WatchColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$currentHoleStrokes',
                  style: WatchTypography.caption.copyWith(
                    color: WatchColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Navigation button widget.
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _NavButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final color = isPrimary
        ? WatchColors.accent
        : (isEnabled ? WatchColors.onBackgroundSecondary : WatchColors.onBackgroundTertiary);

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: '$label button',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: WatchSpacing.minTouchTarget,
            minHeight: WatchSpacing.minTouchTarget,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: WatchTypography.navButton.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
