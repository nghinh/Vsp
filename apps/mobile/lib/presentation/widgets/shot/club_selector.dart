// Club Selector — VSP Mobile App
//
// Bottom sheet widget for selecting a club from the active bag.
// Used in ShotEntrySheet for assigning a club to a shot.
//
// Per Story 10.3 — Slice 2: UI — Shot Entry
//
// UX requirements:
//  - 2-tap flow: tap to open selector, tap to select club
//  - Minimum 44pt iOS / 48dp Android touch targets
//  - Semantics labels for screen readers
//  - Shows club type icon, name, and carry distance

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../features/bag/data/bag_dto.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';

/// Bottom sheet club selector for shot entry.
///
/// Displays clubs from the active bag grouped by type.
/// Returns the selected [ClubDTO].
///
/// Usage:
/// ```dart
/// final club = await ClubSelector.show(context, clubs: activeBag.clubs);
/// if (club != null) {
///   // Use selected club
/// }
/// ```
class ClubSelector extends StatelessWidget {
  /// List of clubs to display.
  final List<ClubDTO> clubs;

  /// Currently selected club (for highlighting).
  final ClubDTO? selectedClub;

  /// Callback when a club is selected.
  final ValueChanged<ClubDTO> onSelected;

  const ClubSelector({
    super.key,
    required this.clubs,
    this.selectedClub,
    required this.onSelected,
  });

  /// Show the club selector as a modal bottom sheet.
  static Future<ClubDTO?> show(
    BuildContext context, {
    required List<ClubDTO> clubs,
    ClubDTO? selectedClub,
  }) {
    return showModalBottomSheet<ClubDTO>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ClubSelector(
        clubs: clubs,
        selectedClub: selectedClub,
        onSelected: (club) => Navigator.of(context).pop(club),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Group clubs by type
    final clubsByType = <ClubType, List<ClubDTO>>{};
    for (final club in clubs) {
      clubsByType.putIfAbsent(club.clubType, () => []).add(club);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: VspSpacing.md),

            // Title
            Text(
              AppLocalizations.of(context).commonSelectClub,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.sm),

            // Subtitle
            Text(
              '${clubs.length} clubs in your bag',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.md),

            // Club list (grouped)
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final type in ClubType.values)
                    if (clubsByType.containsKey(type)) ...[
                      // Section header
                      Padding(
                        padding: const EdgeInsets.only(
                          top: VspSpacing.sm,
                          bottom: VspSpacing.xs,
                        ),
                        child: Text(
                          type.displayName,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Clubs of this type
                      for (final club in clubsByType[type]!)
                        _ClubListTile(
                          club: club,
                          isSelected: club.id == selectedClub?.id,
                          onTap: () => onSelected(club),
                        ),
                    ],
                ],
              ),
            ),

            const SizedBox(height: VspSpacing.sm),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubListTile extends StatelessWidget {
  final ClubDTO club;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClubListTile({
    required this.club,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label:
          '${club.clubType.displayName}, carry distance ${club.formatCarryDistance(context.distanceUnit)}',
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: VspSpacing.xs),
        child: Material(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Club type icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _clubTypeColor(club.clubType).withOpacity(0.15),
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
                          club.clubType.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (club.loft != null)
                          Text(
                            '${club.loft!.toStringAsFixed(1)}° loft',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer.withOpacity(
                                      0.8,
                                    )
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Carry distance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        club.formatCarryDistance(context.distanceUnit),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.primary,
                        ),
                      ),
                      Text(
                        'carry',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  if (isSelected) ...[
                    const SizedBox(width: VspSpacing.sm),
                    Icon(
                      Icons.check_circle,
                      color: colorScheme.primary,
                      size: VspIconSize.md,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _clubTypeIcon(ClubType type) {
    switch (type) {
      case ClubType.driver:
      case ClubType.wood:
      case ClubType.hybrid:
      case ClubType.iron:
      case ClubType.wedge:
        return Icons.golf_course;
      case ClubType.putter:
        return Icons.sports_golf;
    }
  }

  Color _clubTypeColor(ClubType type) {
    switch (type) {
      case ClubType.driver:
        return const Color(0xFFEA580C);
      case ClubType.wood:
        return const Color(0xFFF97316);
      case ClubType.hybrid:
        return const Color(0xFF059669);
      case ClubType.iron:
        return const Color(0xFF3B82F6);
      case ClubType.wedge:
        return const Color(0xFF8B5CF6);
      case ClubType.putter:
        return const Color(0xFF6B7280);
    }
  }
}
