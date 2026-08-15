// Club Type Picker — VSP Mobile App
//
// Bottom sheet picker for selecting a golf club type.
// Mirrors the SkillLevelPicker pattern from ProfileScreen.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/bag_dto.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Bottom sheet picker for club type selection.
class ClubTypePicker extends StatelessWidget {
  final ClubType? selectedType;
  final ValueChanged<ClubType> onChanged;

  const ClubTypePicker({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  /// Show the club type picker as a modal bottom sheet.
  static Future<ClubType?> show(BuildContext context, {ClubType? current}) {
    return showModalBottomSheet<ClubType>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ClubTypePicker(
        selectedType: current,
        onChanged: (type) => Navigator.of(context).pop(type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              AppLocalizations.of(context).clubTypeSelect,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.md),

            // Club type list
            ...ClubType.values.map((type) {
              final isSelected = type == selectedType;
              return Padding(
                padding: const EdgeInsets.only(bottom: VspSpacing.sm),
                child: Semantics(
                  label:
                      '${type.displayName}, ${isSelected ? "selected" : "tap to select"}',
                  button: true,
                  child: InkWell(
                    onTap: () => onChanged(type),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surface,
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
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _typeColor(type).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.golf_course,
                              color: _typeColor(type),
                              size: VspIconSize.md,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  _typeDescription(type),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                              .withOpacity(0.8)
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                              size: VspIconSize.md,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

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

  Color _typeColor(ClubType type) {
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

  String _typeDescription(ClubType type) {
    switch (type) {
      case ClubType.driver:
        return 'Maximum distance off the tee';
      case ClubType.wood:
        return 'Long approach shots and tee shots';
      case ClubType.hybrid:
        return 'Versatile alternative to long irons';
      case ClubType.iron:
        return 'Precision shots from fairway';
      case ClubType.wedge:
        return 'Short game and bunker play';
      case ClubType.putter:
        return 'On the green';
    }
  }
}
