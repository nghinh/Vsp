// Club Card — VSP Mobile App
//
// Card widget showing a club's type icon, loft, and distances.
// Dispersion is Phase 2 scope — stored but NOT displayed per the plan.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/bag_dto.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/bag/domain/club_naming.dart';

/// A card displaying a single club with its key data.
class ClubCard extends StatelessWidget {
  final ClubDTO club;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ClubCard({
    super.key,
    required this.club,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label:
          '${club.displayName}, loft ${club.loft ?? "not set"} degrees, '
          'carry ${club.formatCarryDistance(context.distanceUnit)}',
      button: true,
      child: Dismissible(
        key: Key('club_${club.id}'),
        direction: onDelete != null
            ? DismissDirection.endToStart
            : DismissDirection.none,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: VspSpacing.md),
          color: colorScheme.error,
          child: Icon(Icons.delete, color: colorScheme.onError),
        ),
        confirmDismiss: (_) async {
          if (onDelete != null) {
            final confirmed = await _showDeleteConfirmation(context);
            if (confirmed) onDelete!();
          }
          return false;
        },
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
                // Club type icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _clubTypeColor(club.clubType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _clubTypeIcon(club.clubType),
                    color: _clubTypeColor(club.clubType),
                    size: VspIconSize.md,
                  ),
                ),
                const SizedBox(width: 12),

                // Club info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // "Sắt 7", not "Iron" for all eight of them.
                        club.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: VspSpacing.half),
                      Row(
                        children: [
                          if (club.loft != null) ...[
                            _InfoChip(
                              label: '${club.loft!.toStringAsFixed(1)}°',
                              tooltip: AppLocalizations.of(context).clubLoftTooltip,
                            ),
                            const SizedBox(width: VspSpacing.xs),
                          ],
                          _InfoChip(
                            label: club.formatCarryDistance(
                              context.distanceUnit,
                            ),
                            tooltip: AppLocalizations.of(context).clubCarryTooltip,
                            isPrimary: true,
                          ),
                          if (club.totalDistance != null) ...[
                            const SizedBox(width: VspSpacing.xs),
                            _InfoChip(
                              label: club.formatTotalDistance(
                                context.distanceUnit,
                              ),
                              tooltip: AppLocalizations.of(context).clubTotalTooltip,
                            ),
                          ],
                        ],
                      ),
                      if (club.shaft != null && club.shaft!.isNotEmpty) ...[
                        const SizedBox(height: VspSpacing.half),
                        Text(
                          club.shaft!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: VspIconSize.md,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _clubTypeIcon(ClubType type) {
    // Use a consistent golf icon; club-type-specific icons can be added later
    return Icons.golf_course;
  }

  Color _clubTypeColor(ClubType type) {
    switch (type) {
      case ClubType.driver:
        return const Color(0xFFEA580C); // Orange
      case ClubType.wood:
        return const Color(0xFFF97316); // Light orange
      case ClubType.hybrid:
        return const Color(0xFF059669); // Emerald
      case ClubType.iron:
        return const Color(0xFF3B82F6); // Blue
      case ClubType.wedge:
        return const Color(0xFF8B5CF6); // Purple
      case ClubType.putter:
        return const Color(0xFF6B7280); // Gray
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).clubDeleteTitle),
            content: Text(
              AppLocalizations.of(context).clubDeleteConfirm(club.displayName),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context).commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(AppLocalizations.of(context).commonDelete),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool isPrimary;

  const _InfoChip({
    required this.label,
    required this.tooltip,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '$tooltip: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VspSpacing.sm,
          vertical: VspSpacing.half,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isPrimary
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
