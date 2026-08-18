// DirectionalStatsCard — VSP Mobile App
//
// Card displaying directional deviation statistics (left/right and short/long).
// Per Story 11.1 AC-1 and Slice 3.
//
// Shows: left/right avg ± stdDev, short/long avg ± stdDev.

import 'package:flutter/material.dart';

import '../../../../domain/models/performance/club_performance_stats.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Card showing directional deviation statistics.
/// Per Story 11.1 AC-1: left/right and short/long deviation.
class DirectionalStatsCard extends StatelessWidget {
  final ClubPerformanceStats stats;

  const DirectionalStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: _semanticLabel(context.distanceUnit),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).directionalDeviation,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Left/Right row
            _DirectionalRow(
              icon: Icons.swap_horiz,
              label: AppLocalizations.of(context).performanceLeftRight,
              description: AppLocalizations.of(
                context,
              ).performanceLeftRightHint,
              avg: stats.formatLeftRight(context.distanceUnit),
              stdDev: stats.leftRightStdDev != null
                  ? MeasureUnits.formatTolerance(
                      stats.leftRightStdDev!.abs(), context.distanceUnit)
                  : '—',
              isLeftNegative: (stats.leftRightAvg ?? 0) < 0,
            ),

            const SizedBox(height: 12),
            Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 12),

            // Short/Long row
            _DirectionalRow(
              icon: Icons.straighten,
              label: AppLocalizations.of(context).performanceShortLong,
              description: AppLocalizations.of(
                context,
              ).performanceShortLongHint,
              avg: stats.formatShortLong(context.distanceUnit),
              stdDev: stats.shortLongStdDev != null
                  ? MeasureUnits.formatTolerance(
                      stats.shortLongStdDev!.abs(), context.distanceUnit)
                  : '—',
              isLeftNegative: (stats.shortLongAvg ?? 0) < 0,
            ),
          ],
        ),
      ),
    );
  }

  String _semanticLabel(DistanceUnit unit) {
    return 'Directional deviation: '
        'left/right ${stats.formatLeftRight(unit)}, '
        'short/long ${stats.formatShortLong(unit)}';
  }
}

class _DirectionalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final String avg;
  final String stdDev;
  final bool isLeftNegative;

  const _DirectionalRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.avg,
    required this.stdDev,
    required this.isLeftNegative,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DirectionIndicator(isNegative: isLeftNegative),
                const SizedBox(width: 4),
                Text(
                  avg,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              stdDev,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Visual indicator showing direction tendency.
class _DirectionIndicator extends StatelessWidget {
  final bool isNegative;

  const _DirectionIndicator({required this.isNegative});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isNegative) {
      return Icon(Icons.arrow_back, size: 14, color: colorScheme.tertiary);
    }
    return Icon(Icons.arrow_forward, size: 14, color: colorScheme.primary);
  }
}
