// Hole Score Header — VSP Mobile App
//
// Header widget for the scorecard screen showing hole number, par, and sync status.
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:flutter/material.dart';

import '../common/offline_indicator.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Header widget for the scorecard screen.
class HoleScoreHeader extends StatelessWidget {
  /// Current hole number (1-based).
  final int holeNumber;

  /// Total number of holes.
  final int totalHoles;

  /// Par for the current hole.
  final int? par;

  /// Whether there are offline changes.
  final bool isOffline;

  const HoleScoreHeader({
    super.key,
    required this.holeNumber,
    required this.totalHoles,
    this.par,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Hole number and par
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: AppLocalizations.of(context).holeOfTotal('$holeNumber', '$totalHoles'),
                  child: Text(
                    AppLocalizations.of(context).holeNumberLabel('$holeNumber'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context).holeParLabel('${par ?? '—'}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // Hole progress indicator
          Semantics(
            label: AppLocalizations.of(context).holeOfTotal('$holeNumber', '$totalHoles'),
            child: Text(
              '$holeNumber / $totalHoles',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Offline indicator
          OfflineIndicator(isOffline: isOffline),
        ],
      ),
    );
  }
}
