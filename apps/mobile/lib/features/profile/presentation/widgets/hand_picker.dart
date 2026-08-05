// Hand Picker — VSP Mobile App
//
// Toggle between LEFT and RIGHT dominant hand.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/profile_dto.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Dominant hand toggle — LEFT / RIGHT.
class HandPicker extends StatelessWidget {
  final DominantHand selectedHand;
  final ValueChanged<DominantHand> onChanged;

  const HandPicker({
    super.key,
    required this.selectedHand,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context).profileHandCurrent(selectedHand.value),
      button: true,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HandOption(
              label: AppLocalizations.of(context).handLeft,
              isSelected: selectedHand == DominantHand.left,
              onTap: () => onChanged(DominantHand.left),
              isLeft: true,
            ),
            _HandOption(
              label: AppLocalizations.of(context).handRight,
              isSelected: selectedHand == DominantHand.right,
              onTap: () => onChanged(DominantHand.right),
              isLeft: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _HandOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLeft;

  const _HandOption({
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
