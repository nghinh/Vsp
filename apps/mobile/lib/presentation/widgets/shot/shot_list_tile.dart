// Shot List Tile — VSP Mobile App
//
// Reusable widget for displaying a shot in a list (ShotReviewScreen).
// Shows club, lie, distance, result, confidence badge, and sync status.
//
// Per Story 10.3 — Slice 3: UI — Shot Review + Edit
//
// UX requirements:
//  - Semantics labels for screen readers
//  - 44/48pt touch targets
//  - Sync status indicator (pending/synced/failed)

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../domain/models/shot.dart';
import '../../../domain/models/course_hole_detection.dart';
import '../../../domain/models/sync_status.dart';
import '../detection_confidence_indicator.dart';
import '../sync_status_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Widget for displaying a shot in a list.
class ShotListTile extends StatelessWidget {
  /// The shot to display.
  final Shot shot;

  /// Club name (optional, for display).
  final String? clubName;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Callback when edit is tapped.
  final VoidCallback? onEdit;

  /// Callback when delete is tapped.
  final VoidCallback? onDelete;

  /// Callback when retry sync is tapped.
  final VoidCallback? onRetrySync;

  const ShotListTile({
    super.key,
    required this.shot,
    this.clubName,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onRetrySync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: _semanticLabelIn(context.distanceUnit),
      button: true,
      child: Material(
        color: colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                // Shot number badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${shot.shotNumber}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Shot details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Club and lie row
                      Row(
                        children: [
                          if (clubName != null) ...[
                            Icon(
                              Icons.golf_course,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                clubName!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else
                            Text(
                              'No club',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          const SizedBox(width: VspSpacing.sm),
                          if (shot.lie != null) _LieBadge(lie: shot.lie!),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Distance and result row
                      Row(
                        children: [
                          if (shot.canonicalDistanceMeters != null) ...[
                            Text(
                              context.formatDistance(shot.canonicalDistanceMeters),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: VspSpacing.sm),
                          ],
                          if (shot.result != null)
                            _ResultBadge(result: shot.result!),
                          if (shot.isPenalty) ...[
                            const SizedBox(width: VspSpacing.xs),
                            _FlagBadge(
                              icon: Icons.warning_amber_rounded,
                              label: AppLocalizations.of(context).shotPenalty,
                              color: colorScheme.error,
                            ),
                          ],
                          if (shot.isProvisional) ...[
                            const SizedBox(width: VspSpacing.xs),
                            _FlagBadge(
                              icon: Icons.refresh,
                              label: AppLocalizations.of(context).shotProvisional,
                              color: Colors.orange,
                            ),
                          ],
                          if (shot.isMulligan) ...[
                            const SizedBox(width: VspSpacing.xs),
                            _FlagBadge(
                              icon: Icons.replay,
                              label: AppLocalizations.of(context).shotMulligan,
                              color: Colors.purple,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Confidence badge (if not manual)
                if (shot.source != ShotSource.manual && shot.confidence != null)
                  DetectionConfidenceIndicator(
                    level: _confidenceLevel(shot.confidence!),
                    confidence: shot.confidence,
                  ),

                const SizedBox(width: VspSpacing.sm),

                // Sync status
                SyncStatusBadge(
                  status: shot.syncStatus,
                  compact: true,
                  onRetry: shot.syncStatus == SyncStatus.failed
                      ? onRetrySync
                      : null,
                ),

                // Edit button
                if (onEdit != null) ...[
                  const SizedBox(width: VspSpacing.xs),
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: AppLocalizations.of(context).shotEditTooltip,
                    constraints: const BoxConstraints(
                      minWidth: VspSpacingSemantic.touchTargetMin,
                      minHeight: VspSpacingSemantic.touchTargetMin,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabelIn(DistanceUnit unit) {
    final parts = <String>[];
    parts.add('Shot ${shot.shotNumber}');
    if (clubName != null) parts.add(clubName!);
    if (shot.lie != null) parts.add('lie: ${shot.lie!.name}');
    if (shot.canonicalDistanceMeters != null) {
      parts.add(MeasureUnits.format(shot.canonicalDistanceMeters!, unit));
    }
    if (shot.result != null) parts.add('result: ${shot.result!.name}');
    if (shot.isPenalty) parts.add('penalty');
    if (shot.isProvisional) parts.add('provisional');
    if (shot.isMulligan) parts.add('mulligan');
    parts.add('sync status: ${shot.syncStatus.name}');
    return parts.join(', ');
  }

  ConfidenceLevel _confidenceLevel(double confidence) {
    if (confidence >= 0.85) return ConfidenceLevel.veryHigh;
    if (confidence >= 0.70) return ConfidenceLevel.high;
    if (confidence >= 0.50) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}

class _LieBadge extends StatelessWidget {
  final ShotLie lie;

  const _LieBadge({required this.lie});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _lieLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String get _lieLabel {
    switch (lie) {
      case ShotLie.teebox:
        return 'Tee';
      case ShotLie.fairway:
        return 'Fairway';
      case ShotLie.rough:
        return 'Rough';
      case ShotLie.bunker:
        return 'Bunker';
      case ShotLie.water:
        return 'Water';
      case ShotLie.penalty:
        return 'Penalty';
      case ShotLie.green:
        return 'Green';
      case ShotLie.putt:
        return 'Putt';
      case ShotLie.outOfBounds:
        return 'OB';
      case ShotLie.cartPath:
        return 'Cart Path';
      default:
        return lie.name;
    }
  }
}

class _ResultBadge extends StatelessWidget {
  final ShotResult result;

  const _ResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _resultColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _resultLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String get _resultLabel {
    switch (result) {
      case ShotResult.fairwayHit:
        return 'Fwy Hit';
      case ShotResult.greenHit:
        return 'GIR';
      case ShotResult.inBunker:
        return 'Bunker';
      case ShotResult.inWater:
        return 'Water';
      case ShotResult.outOfBounds:
        return 'OB';
      case ShotResult.penalty:
        return 'Penalty';
      case ShotResult.mulligan:
        return 'Mulligan';
      case ShotResult.provisional:
        return 'Provisional';
      case ShotResult.scrambleSave:
        return 'Scramble';
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

class _FlagBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FlagBadge({
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
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
