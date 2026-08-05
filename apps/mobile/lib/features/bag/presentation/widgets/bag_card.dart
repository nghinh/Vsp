// Bag Card — VSP Mobile App
//
// Card widget showing a bag's name, active badge, and club count.
// Tap navigates to bag detail; swipe-to-delete supported.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/bag_dto.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A card displaying bag name, active badge, and club count.
class BagCard extends StatelessWidget {
  final BagDTO bag;
  final VoidCallback? onTap;
  final VoidCallback? onSetActive;
  final VoidCallback? onDelete;

  const BagCard({
    super.key,
    required this.bag,
    this.onTap,
    this.onSetActive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label:
          '${bag.name} bag, ${bag.clubCount} clubs, ${bag.isActive ? "active" : "not active"}',
      button: true,
      child: Dismissible(
        key: Key('bag_${bag.id}'),
        direction: bag.clubs.isEmpty
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
              border: Border.all(
                color: bag.isActive
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: bag.isActive ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Bag icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bag.isActive
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.golf_course,
                    color: bag.isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    size: VspIconSize.md,
                  ),
                ),
                const SizedBox(width: 12),

                // Bag info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bag.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (bag.isActive) ...[
                            const SizedBox(width: VspSpacing.xs),
                            _ActiveBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: VspSpacing.half),
                      Text(
                        '${bag.clubCount} ${bag.clubCount == 1 ? "club" : "clubs"}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Set Active button (only shown if not already active)
                if (!bag.isActive && onSetActive != null) ...[
                  const SizedBox(width: VspSpacing.sm),
                  TextButton(
                    onPressed: onSetActive,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        VspSpacingSemantic.touchTargetMin,
                        VspSpacingSemantic.touchTargetMin,
                      ),
                    ),
                    child: Text(AppLocalizations.of(context).bagSetActive),
                  ),
                ],

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

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).bagDeleteTitle),
            content: Text(
              'Are you sure you want to delete "${bag.name}"? This cannot be undone.',
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

class _ActiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.half,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: colorScheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
