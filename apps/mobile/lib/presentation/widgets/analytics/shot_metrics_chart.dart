// Shot Metrics Chart — VSP Mobile App
//
// Club usage and distance distribution chart for Round Review.
// Per Story 11.2 AC3: accessible charts with legend and non-color indicators.

import 'package:flutter/material.dart';

import '../../../domain/models/shot_metrics.dart';
import 'accessible_bar_chart.dart';
import 'accessible_pie_chart.dart';

/// Chart widget showing shot metrics (club usage and distance distribution).
///
/// Per AC3: legend, pattern fills, shape-coded legends, aria-labels.
class ShotMetricsChart extends StatelessWidget {
  final ShotMetrics metrics;

  const ShotMetricsChart({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.clubMetrics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Club usage bar chart
        _ClubUsageSection(metrics: metrics),
        const SizedBox(height: 24),
        // Distance distribution per club
        if (metrics.mostUsedClub != null)
          _DistanceDistributionSection(clubMetrics: metrics.mostUsedClub!),
        const SizedBox(height: 24),
        // Lie distribution pie chart
        if (metrics.mostUsedClub != null &&
            metrics.mostUsedClub!.lieDistribution.isNotEmpty)
          _LieDistributionSection(
            lieDistribution: metrics.mostUsedClub!.lieDistribution,
          ),
      ],
    );
  }
}

class _ClubUsageSection extends StatelessWidget {
  final ShotMetrics metrics;

  const _ClubUsageSection({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final groups = metrics.clubMetrics.map((club) {
      return BarChartGroup(
        label: club.clubName ?? club.clubId,
        values: [club.totalShots.toDouble()],
        patternKey: club.clubId,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Club Usage', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        AccessibleBarChart(
          groups: groups,
          yAxisLabel: 'Shots',
          title: 'Club usage distribution chart',
        ),
      ],
    );
  }
}

class _DistanceDistributionSection extends StatelessWidget {
  final ClubShotMetrics clubMetrics;

  const _DistanceDistributionSection({required this.clubMetrics});

  @override
  Widget build(BuildContext context) {
    final sections = clubMetrics.distanceDistribution.map((bucket) {
      return PieChartSection(
        label: bucket.label,
        value: bucket.percentage,
        patternName: bucket.label,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distance Distribution — ${clubMetrics.clubName ?? clubMetrics.clubId}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (sections.isNotEmpty)
          AccessiblePieChart(
            sections: sections,
            title:
                'Distance distribution pie chart for ${clubMetrics.clubName ?? clubMetrics.clubId}',
          ),
        const SizedBox(height: 12),
        // Distance stats
        _DistanceStatsRow(clubMetrics: clubMetrics),
      ],
    );
  }
}

class _DistanceStatsRow extends StatelessWidget {
  final ClubShotMetrics clubMetrics;

  const _DistanceStatsRow({required this.clubMetrics});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          label: 'Avg',
          value:
              '${clubMetrics.averageDistanceYards?.toStringAsFixed(1) ?? '-'} yds',
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'Med',
          value:
              '${clubMetrics.medianDistanceYards?.toStringAsFixed(1) ?? '-'} yds',
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: 'Std Dev',
          value:
              '${clubMetrics.standardDeviationYards?.toStringAsFixed(1) ?? '-'} yds',
        ),
        if (clubMetrics.consistencyScore != null) ...[
          const SizedBox(width: 8),
          _StatChip(
            label: 'Consistency',
            value: '${clubMetrics.consistencyScore!.toStringAsFixed(0)}%',
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LieDistributionSection extends StatelessWidget {
  final List<LieDistribution> lieDistribution;

  const _LieDistributionSection({required this.lieDistribution});

  @override
  Widget build(BuildContext context) {
    final sections = lieDistribution.map((lie) {
      return PieChartSection(
        label: lie.lie,
        value: lie.percentage,
        patternName: lie.lie,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lie Distribution',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        AccessiblePieChart(
          sections: sections,
          title: 'Lie distribution pie chart',
        ),
      ],
    );
  }
}
