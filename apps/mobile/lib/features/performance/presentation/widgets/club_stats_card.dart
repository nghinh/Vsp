// ClubStatsCard — VSP Mobile App
//
// Card displaying club performance statistics.
// Per Story 11.1 AC-1 and Slice 3.
//
// Displays: carry avg/median, total avg/median, variability (stdDev).

import 'package:flutter/material.dart';

import '../../../../domain/models/performance/club_performance_stats.dart';
import 'sample_size_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Card showing club distance statistics.
/// Per NFR-4: semantic labels for accessibility.
class ClubStatsCard extends StatelessWidget {
  final ClubPerformanceStats stats;
  final VoidCallback? onViewDispersion;

  const ClubStatsCard({
    super.key,
    required this.stats,
    this.onViewDispersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unit = context.distanceUnit;

    return Semantics(
      label: _semanticLabel(unit),
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
            // Header with sample size badge
            _buildHeader(context),
            const SizedBox(height: 16),

            // Carry distance stats
            _buildDistanceSection(
              context,
              title: AppLocalizations.of(context).performanceCarryDistance,
              avg: stats.formatCarryAvg(unit),
              median: stats.formatCarryMedian(unit),
              variability: stats.formatVariability(unit),
              min: stats.carryMin != null
                  ? MeasureUnits.format(stats.carryMin!, unit)
                  : '—',
              max: stats.carryMax != null
                  ? MeasureUnits.format(stats.carryMax!, unit)
                  : '—',
            ),

            const SizedBox(height: 12),
            Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 12),

            // Total distance stats
            _buildDistanceSection(
              context,
              title: AppLocalizations.of(context).performanceTotalDistance,
              avg: stats.formatTotalAvg(unit),
              median: stats.formatTotalMedian(unit),
              variability: stats.totalStdDev != null
                  ? MeasureUnits.formatTolerance(stats.totalStdDev!, unit)
                  : '—',
              min: stats.totalMin != null
                  ? MeasureUnits.format(stats.totalMin!, unit)
                  : '—',
              max: stats.totalMax != null
                  ? MeasureUnits.format(stats.totalMax!, unit)
                  : '—',
            ),

            // View dispersion button
            if (onViewDispersion != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewDispersion,
                  icon: const Icon(Icons.scatter_plot, size: 18),
                  label: Text(AppLocalizations.of(context).performanceViewDispersion),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Statistics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _computedAtText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SampleSizeBadge(
          label: stats.sampleSizeLabel,
          sampleSize: stats.sampleSize,
        ),
      ],
    );
  }

  Widget _buildDistanceSection(
    BuildContext context, {
    required String title,
    required String avg,
    required String median,
    required String variability,
    required String min,
    required String max,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatItem(label: AppLocalizations.of(context).analyticsAvg, value: avg, isPrimary: true),
            ),
            Expanded(
              child: _StatItem(label: AppLocalizations.of(context).performanceMedian, value: median),
            ),
            Expanded(
              child: _StatItem(label: '± Std Dev', value: variability),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _StatItem(label: AppLocalizations.of(context).performanceMin, value: min, isSmall: true),
            ),
            Expanded(
              child: _StatItem(label: AppLocalizations.of(context).performanceMax, value: max, isSmall: true),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  String _computedAtText() {
    if (stats.computedAt == null) return 'Not yet computed';
    final diff = DateTime.now().difference(stats.computedAt!);
    if (diff.inMinutes < 1) return 'Computed just now';
    if (diff.inMinutes < 60) return 'Computed ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Computed ${diff.inHours}h ago';
    return 'Computed ${diff.inDays}d ago';
  }

  String _semanticLabel(DistanceUnit unit) {
    return 'Club performance: ${stats.sampleSize} shots, '
        'carry average ${stats.formatCarryAvg(unit)}, '
        'total average ${stats.formatTotalAvg(unit)}, '
        'variability ${stats.formatVariability(unit)}';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;
  final bool isSmall;

  const _StatItem({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: isSmall ? 10 : 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
            fontSize: isSmall ? 12 : 14,
          ),
        ),
      ],
    );
  }
}
