// Round Summary Card — VSP Mobile App
//
// Scorecard summary for Round Review screen.
// Per Story 11.2 AC2: gross, putts, penalties, GIR, FIR display.

import 'package:flutter/material.dart';

import '../../../domain/models/round_review_metrics.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Summary card showing scoring metrics for a round.
///
/// Per AC2: displays gross, putts, penalties, GIR, FIR.
class RoundSummaryCard extends StatelessWidget {
  final RoundScoringSummary scoring;

  const RoundSummaryCard({super.key, required this.scoring});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).roundSummaryHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // Score to par
            _ScoreToParRow(scoreToPar: scoring.scoreToPar),
            const Divider(),
            // Main metrics grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _MetricCell(
                  label: AppLocalizations.of(context).analyticsGross,
                  value: '${scoring.totalGrossScore}',
                  icon: Icons.sports_golf,
                ),
                _MetricCell(
                  label: AppLocalizations.of(context).analyticsPutts,
                  value: scoring.totalPutts?.toString() ?? '-',
                  icon: Icons.grass,
                ),
                _MetricCell(
                  label: AppLocalizations.of(context).analyticsPenalties,
                  value: scoring.totalPenalties?.toString() ?? '-',
                  icon: Icons.warning_outlined,
                ),
                _PercentageCell(
                  label: AppLocalizations.of(context).analyticsGir,
                  count: scoring.girCount,
                  total: scoring.girTotal,
                ),
                _PercentageCell(
                  label: AppLocalizations.of(context).analyticsFir,
                  count: scoring.firCount,
                  total: scoring.firTotal,
                ),
                _PercentageCell(
                  label: AppLocalizations.of(context).analyticsUpAndDown,
                  count: scoring.upAndDownCount,
                  total: scoring.upAndDownTotal,
                ),
              ],
            ),
            // Birdie/bogey breakdown
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CountCell(
                  label: AppLocalizations.of(context).analyticsBirdiePlus,
                  count: scoring.birdieOrBetterCount,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                _CountCell(
                  label: AppLocalizations.of(context).analyticsPar,
                  count: scoring.parOrBetterCount,
                  color: Colors.blue,
                ),
                _CountCell(
                  label: AppLocalizations.of(context).analyticsBogeyPlus,
                  count: scoring.bogeyOrWorseCount,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreToParRow extends StatelessWidget {
  final int? scoreToPar;

  const _ScoreToParRow({this.scoreToPar});

  @override
  Widget build(BuildContext context) {
    if (scoreToPar == null) return const SizedBox.shrink();

    final color = scoreToPar! < 0
        ? Theme.of(context).colorScheme.tertiary
        : scoreToPar! > 0
        ? Theme.of(context).colorScheme.error
        : Colors.grey;

    final sign = scoreToPar! > 0 ? '+' : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(AppLocalizations.of(context).analyticsScoreToPar, style: Theme.of(context).textTheme.titleSmall),
        Text(
          '$sign$scoreToPar',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _PercentageCell extends StatelessWidget {
  final String label;
  final int? count;
  final int? total;

  const _PercentageCell({required this.label, this.count, this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (count != null && total != null && total! > 0)
        ? (count! / total! * 100).toStringAsFixed(0)
        : '-';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pct,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          '%',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _CountCell extends StatelessWidget {
  final String label;
  final int? count;
  final Color color;

  const _CountCell({required this.label, this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count?.toString() ?? '-',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
