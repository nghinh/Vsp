// Unit Picker — VSP Mobile App
//
// Toggle between METERS and YARDS distance units.
// Triggers immediate display conversion (AC-2) and queues sync.
//
// Unit conversion: displayValue = unit === 'YARDS'
//   ? canonicalMeters * 1.09361
//   : canonicalMeters
//
// AC-2: Unit changes update displayed distances without corrupting canonical.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/profile_dto.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Unit toggle — METERS / YARDS.
class UnitPicker extends StatelessWidget {
  final DistanceUnit selectedUnit;
  final ValueChanged<DistanceUnit> onChanged;

  const UnitPicker({
    super.key,
    required this.selectedUnit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context).profileUnitCurrent(selectedUnit.value),
      button: true,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UnitOption(
              label: AppLocalizations.of(context).unitMeters,
              isSelected: selectedUnit == DistanceUnit.meters,
              onTap: () => onChanged(DistanceUnit.meters),
              isLeft: true,
            ),
            _UnitOption(
              label: AppLocalizations.of(context).unitYards,
              isSelected: selectedUnit == DistanceUnit.yards,
              onTap: () => onChanged(DistanceUnit.yards),
              isLeft: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLeft;

  const _UnitOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: VspSpacing.md,
          vertical: VspSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(11) : Radius.zero,
            right: !isLeft ? const Radius.circular(11) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
