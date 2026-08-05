// Shot Card — VSP Mobile App
//
// Card widget for displaying a shot in the ShotReviewScreen.
// Shows club, lie, distance, result, markers, and sync status.
//
// Per Story 10.3 — Slice 3: UI — Shot Review + Edit

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../domain/models/shot.dart';
import '../../../domain/models/sync_status.dart';
import '../sync_status_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Card widget for displaying a shot.
class ShotCard extends StatelessWidget {
  /// The shot to display.
  final Shot shot;

  /// Club name (optional, for display).
  final String? clubName;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when edit is tapped.
  final VoidCallback? onEdit;

  /// Callback when delete is tapped.
  final VoidCallback? onDelete;

  /// Callback when merge is tapped.
  final VoidCallback? onMerge;

  /// Callback when retry sync is tapped.
  final VoidCallback? onRetrySync;

  const ShotCard({
    super.key,
    required this.shot,
    this.clubName,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onMerge,
    this.onRetrySync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: VspSpacing.xs,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: shot number, club, sync status
              Row(
                children: [
                  // Shot number badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${shot.shotNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: VspSpacing.sm),

                  // Club name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clubName ?? 'No club assigned',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (shot.lie != null)
                          Text(
                            _lieLabel(shot.lie!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Sync status
                  SyncStatusBadge(
                    status: shot.syncStatus,
                    compact: true,
                    onRetry: shot.syncStatus == SyncStatus.failed
                        ? onRetrySync
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: VspSpacing.sm),

              // Distance and result row
              Row(
                children: [
                  // Distance
                  if (shot.distanceYards != null) ...[
                    _InfoChip(
                      icon: Icons.straighten,
                      label: '${shot.distanceYards!.round()} yd',
                    ),
                    const SizedBox(width: VspSpacing.sm),
                  ],

                  // Result
                  if (shot.result != null) _ResultChip(result: shot.result!),

                  const Spacer(),

                  // Markers
                  if (shot.isPenalty || shot.isProvisional || shot.isMulligan)
                    Row(
                      children: [
                        if (shot.isPenalty)
                          _MarkerChip(
                            icon: Icons.warning_amber_rounded,
                            label: AppLocalizations.of(context).shotPenalty,
                            color: colorScheme.error,
                          ),
                        if (shot.isProvisional) ...[
                          const SizedBox(width: 4),
                          _MarkerChip(
                            icon: Icons.refresh,
                            label: AppLocalizations.of(context).shotProvisional,
                            color: Colors.orange,
                          ),
                        ],
                        if (shot.isMulligan) ...[
                          const SizedBox(width: 4),
                          _MarkerChip(
                            icon: Icons.replay,
                            label: AppLocalizations.of(context).shotMulligan,
                            color: Colors.purple,
                          ),
                        ],
                      ],
                    ),
                ],
              ),

              // Action buttons
              if (onEdit != null || onDelete != null || onMerge != null) ...[
                const SizedBox(height: VspSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: VspSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onMerge != null)
                      TextButton.icon(
                        onPressed: onMerge,
                        icon: const Icon(Icons.merge_type, size: 18),
                        label: Text(AppLocalizations.of(context).shotMerge),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (onEdit != null)
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(AppLocalizations.of(context).shotEdit),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        label: Text(
                          'Delete',
                          style: TextStyle(color: colorScheme.error),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _lieLabel(ShotLie lie) {
    switch (lie) {
      case ShotLie.teebox:
        return 'Tee box';
      case ShotLie.fairway:
        return 'Fairway';
      case ShotLie.rough:
        return 'Rough';
      case ShotLie.bunker:
        return 'Bunker';
      case ShotLie.water:
        return 'Water hazard';
      case ShotLie.penalty:
        return 'Penalty area';
      case ShotLie.green:
        return 'Green';
      case ShotLie.putt:
        return 'Putting';
      case ShotLie.outOfBounds:
        return 'Out of bounds';
      case ShotLie.cartPath:
        return 'Cart path';
      default:
        return lie.name;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.half,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final ShotResult result;

  const _ResultChip({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _resultColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.half,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _resultLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String get _resultLabel {
    switch (result) {
      case ShotResult.fairwayHit:
        return 'Fairway Hit';
      case ShotResult.greenHit:
        return 'GIR';
      case ShotResult.inBunker:
        return 'In Bunker';
      case ShotResult.inWater:
        return 'In Water';
      case ShotResult.outOfBounds:
        return 'OB';
      case ShotResult.penalty:
        return 'Penalty';
      case ShotResult.mulligan:
        return 'Mulligan';
      case ShotResult.provisional:
        return 'Provisional';
      case ShotResult.scrambleSave:
        return 'Scramble Save';
      case ShotResult.chipIn:
        return 'Chip In';
      case ShotResult.holeOut:
        return 'Hole Out';
      case ShotResult.inTheHole:
        return 'In the Hole!';
      default:
        return result.name;
    }
  }

  Color _resultColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (result) {
      case ShotResult.fairwayHit:
      case ShotResult.greenHit:
      case ShotResult.scrambleSave:
      case ShotResult.chipIn:
      case ShotResult.holeOut:
      case ShotResult.inTheHole:
        return Colors.green;
      case ShotResult.inBunker:
      case ShotResult.inWater:
      case ShotResult.outOfBounds:
      case ShotResult.penalty:
        return colorScheme.error;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }
}

class _MarkerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MarkerChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
