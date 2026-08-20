// ClubStatsCard — VSP Mobile App
//
// Card displaying club performance statistics.
// Per Story 11.1 AC-1 and Slice 3.
//
// Displays: carry avg/median, total avg/median, variability (stdDev).

import 'package:flutter/material.dart';
import 'package:vsp_mobile/core/l10n/relative_time.dart';

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
      label: _semanticLabel(context, unit),
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
                AppLocalizations.of(context).performanceStatsHeading,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _computedAtText(context),
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

  /// When these figures were last computed.
  ///
  /// Was a private relative-time formatter emitting English — "Computed 3h
  /// ago" — beside a Vietnamese screen. `RelativeTime` already does this
  /// against l10n, handles clock skew, and is what every other timestamp in
  /// the app goes through; a second implementation is a second thing to
  /// translate and a second thing to get wrong.
  String _computedAtText(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final computedAt = stats.computedAt;
    if (computedAt == null) return l10n.performanceNotComputed;
    return RelativeTime.format(l10n, computedAt);
  }

  String _semanticLabel(BuildContext context, DistanceUnit unit) {
    return AppLocalizations.of(context).performanceClubStatsSemantics(
      '${stats.sampleSize}',
      stats.formatCarryAvg(unit),
      stats.formatTotalAvg(unit),
      stats.formatVariability(unit),
    );
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
