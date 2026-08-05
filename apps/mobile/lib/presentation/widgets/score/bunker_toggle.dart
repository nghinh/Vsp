// Bunker Toggle — VSP Mobile App
//
// Toggle widget for bunker shot statistic.
// Non-color-only: uses icons with text labels per AC-3.
//
// Animation: 150–200ms subtle reveal.
//
// Story 5.3 — Slice 4: Progressive Disclosure

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fairway_gir_toggle.dart' show StatToggleState;
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Minimum touch target size in logical pixels (44pt iOS / 48dp Android).
const double kMinTouchTarget = 44.0;

/// Widget for bunker shot toggle (yes/no).
class BunkerToggle extends StatelessWidget {
  /// Current state of the bunker toggle.
  final StatToggleState state;

  /// Callback when bunker toggled to yes.
  final VoidCallback onToggleYes;

  /// Callback when bunker toggled to no.
  final VoidCallback onToggleNo;

  /// Callback when bunker is cleared.
  final VoidCallback onClear;

  /// Accessibility label.
  final String semanticLabel;

  const BunkerToggle({
    super.key,
    required this.state,
    required this.onToggleYes,
    required this.onToggleNo,
    required this.onClear,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            AppLocalizations.of(context).scoreBunker,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),

          const SizedBox(width: 12),

          // Yes button
          _BunkerButton(
            label: AppLocalizations.of(context).scoreYes,
            isSelected: state == StatToggleState.yes,
            color: theme.colorScheme.secondaryContainer,
            selectedColor: theme.colorScheme.secondary,
            onTap: () {
              HapticFeedback.lightImpact();
              onToggleYes();
            },
          ),

          const SizedBox(width: 8),

          // No button
          _BunkerButton(
            label: 'No',
            isSelected: state == StatToggleState.no,
            color: theme.colorScheme.surfaceContainerHighest,
            selectedColor: theme.colorScheme.error,
            onTap: () {
              HapticFeedback.lightImpact();
              onToggleNo();
            },
          ),

          // Clear button (only when set)
          if (state != StatToggleState.unset) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onClear();
              },
              child: Text(
                AppLocalizations.of(context).scorecardClear,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BunkerButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final Color selectedColor;
  final VoidCallback onTap;

  const _BunkerButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final backgroundColor = isSelected ? selectedColor : color;
    final foregroundColor = isSelected
        ? theme.colorScheme.onSecondary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: '${AppLocalizations.of(context).scoreBunker} $label',
      button: true,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: kMinTouchTarget,
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
