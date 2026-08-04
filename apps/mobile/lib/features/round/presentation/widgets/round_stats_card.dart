// RoundStatsCard Widget — VSP Mobile App
//
// Stats card showing fairways hit, GIR, total putts, total penalties.
// Per Story 5.5 Slice 3: AC-2 basic stats display.
//
// Layout: 2x2 grid of stat items.

import 'package:flutter/material.dart';

/// Stats card widget for round summary.
class RoundStatsCard extends StatelessWidget {
  final int fairwaysHit;
  final int par4Or5Count;
  final int girCount;
  final int totalHoles;
  final int totalPutts;
  final int totalPenalties;

  const RoundStatsCard({
    super.key,
    required this.fairwaysHit,
    required this.par4Or5Count,
    required this.girCount,
    required this.totalHoles,
    required this.totalPutts,
    required this.totalPenalties,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round Stats',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Fairways',
                    value: '$fairwaysHit/$par4Or5Count',
                    subValue: par4Or5Count > 0
                        ? '${((fairwaysHit / par4Or5Count) * 100).round()}%'
                        : '—',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'GIR',
                    value: '$girCount/$totalHoles',
                    subValue: totalHoles > 0
                        ? '${((girCount / totalHoles) * 100).round()}%'
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatItem(label: 'Total Putts', value: '$totalPutts'),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Penalties',
                    value: '$totalPenalties',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;

  const _StatItem({required this.label, required this.value, this.subValue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subValue != null) ...[
              const SizedBox(width: 4),
              Text(
                subValue!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
