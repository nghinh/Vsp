// Fairway/GIR Toggle — VSP Mobile App
//
// Toggle widget for fairway hit and green-in-regulation (GIR) statistics.
// Non-color-only: uses ✓/✗ icons with text labels per AC-3.
//
// Animation: 150–200ms subtle reveal.
//
// Story 5.3 — Slice 4: Progressive Disclosure

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Minimum touch target size in logical pixels (44pt iOS / 48dp Android).
const double kMinTouchTarget = 44.0;

/// Toggle state for a boolean stat field.
enum StatToggleState {
  /// Field is unset/null.
  unset,

  /// Field is true (achieved).
  yes,

  /// Field is false (not achieved).
  no,
}

/// Widget for a single boolean stat toggle (fairway hit, GIR).
class StatToggle extends StatelessWidget {
  /// Display label for the stat.
  final String label;

  /// Current state of the toggle.
  final StatToggleState state;

  /// Callback when toggled to yes/true.
  final VoidCallback onToggleYes;

  /// Callback when toggled to no/false.
  final VoidCallback onToggleNo;

  /// Callback to clear the toggle back to unset.
  final VoidCallback onClear;

  /// Accessibility label for this toggle.
  final String semanticLabel;

  const StatToggle({
    super.key,
    required this.label,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),

          const SizedBox(height: 4),

          // Toggle buttons row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Yes/True button
              _ToggleButton(
                icon: Icons.check,
                label: AppLocalizations.of(context).scoreYes,
                isSelected: state == StatToggleState.yes,
                selectedColor: theme.colorScheme.primaryContainer,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggleYes();
                },
              ),

              const SizedBox(width: 4),

              // No/False button
              _ToggleButton(
                icon: Icons.close,
                label: AppLocalizations.of(context).scoreNo,
                isSelected: state == StatToggleState.no,
                selectedColor: theme.colorScheme.errorContainer,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggleNo();
                },
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Clear button (only when set)
          if (state != StatToggleState.unset)
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
            )
          else
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final backgroundColor = isSelected
        ? selectedColor
        : theme.colorScheme.surfaceContainerHighest;
    final foregroundColor = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: '$label${isSelected ? ' selected' : ''}',
      button: true,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: kMinTouchTarget,
            height: kMinTouchTarget,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: foregroundColor),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Combined widget for fairway hit and GIR toggles side by side.
class FairwayGirToggles extends StatelessWidget {
  /// Fairway hit state.
  final StatToggleState fairwayState;

  /// GIR state.
  final StatToggleState girState;

  /// Callback when fairway toggled to yes.
  final VoidCallback onFairwayYes;

  /// Callback when fairway toggled to no.
  final VoidCallback onFairwayNo;

  /// Callback when fairway is cleared.
  final VoidCallback onFairwayClear;

  /// Callback when GIR toggled to yes.
  final VoidCallback onGirYes;

  /// Callback when GIR toggled to no.
  final VoidCallback onGirNo;

  /// Callback when GIR is cleared.
  final VoidCallback onGirClear;

  const FairwayGirToggles({
    super.key,
    required this.fairwayState,
    required this.girState,
    required this.onFairwayYes,
    required this.onFairwayNo,
    required this.onFairwayClear,
    required this.onGirYes,
    required this.onGirNo,
    required this.onGirClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          StatToggle(
            label: AppLocalizations.of(context).scoreFairway,
            state: fairwayState,
            onToggleYes: onFairwayYes,
            onToggleNo: onFairwayNo,
            onClear: onFairwayClear,
            semanticLabel: AppLocalizations.of(context).scoreFairwayHit,
          ),
          Container(
            width: 1,
            height: 60,
            color: theme.dividerColor.withOpacity(0.12),
          ),
          StatToggle(
            label: AppLocalizations.of(context).analyticsGir,
            state: girState,
            onToggleYes: onGirYes,
            onToggleNo: onGirNo,
            onClear: onGirClear,
            semanticLabel: AppLocalizations.of(context).scoreGir,
          ),
        ],
      ),
    );
  }
}
