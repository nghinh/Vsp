// ClubPerformanceMiniCard — VSP Mobile App
//
// Mini card showing club performance summary in bag list.
// Per Story 11.1 Slice 3.
//
// Shows: club name, sample size badge, key stats (carry avg).

import 'package:flutter/material.dart';

import '../../../../domain/models/performance/club_performance_stats.dart';
import 'sample_size_badge.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Mini card showing club performance summary for bag-level list view.
class ClubPerformanceMiniCard extends StatelessWidget {
  final ClubPerformanceStats stats;
  final String clubName;
  final VoidCallback? onTap;

  const ClubPerformanceMiniCard({
    super.key,
    required this.stats,
    required this.clubName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context).performanceClubMiniSemantics(
          clubName,
          '${stats.sampleSize}',
          stats.formatCarryAvg(context.distanceUnit)),
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Club icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.golf_course,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Club name and stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clubName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          stats.formatCarryAvg(context.distanceUnit),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context).performanceCarryAvgShort,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          stats.formatVariability(context.distanceUnit),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sample size badge
              SampleSizeBadge(
                label: stats.sampleSizeLabel,
                sampleSize: stats.sampleSize,
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
