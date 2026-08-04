// Penalty Toggle — VSP Mobile App
//
// Toggle widget for penalty, provisional, and mulligan shot markers.
// Non-color-only: uses icons with text labels per AC-3.
//
// Per Story 10.3 — Slice 3: UI — Shot Review + Edit
//
// UX requirements:
//  - Minimum 44pt iOS / 48dp Android touch targets
//  - Semantics labels for screen readers
//  - Haptic feedback on toggle

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_theme/mobile_theme.dart';

/// Toggle state for penalty markers.
enum PenaltyToggleState {
  /// Marker is not set.
  unset,

  /// Marker is set (penalty/provisional/mulligan).
  set,
}

/// Widget for penalty/provisional/mulligan toggle.
class PenaltyToggle extends StatelessWidget {
  /// Label for this toggle (e.g., "Penalty", "Provisional", "Mulligan").
  final String label;

  /// Icon for this toggle.
  final IconData icon;

  /// Current state of the toggle.
  final PenaltyToggleState state;

  /// Callback when toggled on.
  final VoidCallback onToggleOn;

  /// Callback when toggled off.
  final VoidCallback onToggleOff;

  /// Accessibility label.
  final String semanticLabel;

  const PenaltyToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.state,
    required this.onToggleOn,
    required this.onToggleOff,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isSet = state == PenaltyToggleState.set;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: isSet
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (isSet) {
              onToggleOff();
            } else {
              onToggleOn();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: VspSpacingSemantic.touchTargetMin,
              minHeight: VspSpacingSemantic.touchTargetMin,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: VspSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSet ? colorScheme.error : colorScheme.outlineVariant,
                width: isSet ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSet
                      ? colorScheme.onErrorContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isSet
                        ? colorScheme.onErrorContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSet ? FontWeight.w600 : FontWeight.normal,
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

/// Row of penalty/provisional/mulligan toggles.
class PenaltyToggleRow extends StatelessWidget {
  /// Current penalty state.
  final bool isPenalty;

  /// Current provisional state.
  final bool isProvisional;

  /// Current mulligan state.
  final bool isMulligan;

  /// Callback when penalty toggled.
  final ValueChanged<bool> onPenaltyChanged;

  /// Callback when provisional toggled.
  final ValueChanged<bool> onProvisionalChanged;

  /// Callback when mulligan toggled.
  final ValueChanged<bool> onMulliganChanged;

  const PenaltyToggleRow({
    super.key,
    required this.isPenalty,
    required this.isProvisional,
    required this.isMulligan,
    required this.onPenaltyChanged,
    required this.onProvisionalChanged,
    required this.onMulliganChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        PenaltyToggle(
          label: 'Penalty',
          icon: Icons.warning_amber_rounded,
          state: isPenalty ? PenaltyToggleState.set : PenaltyToggleState.unset,
          onToggleOn: () => onPenaltyChanged(true),
          onToggleOff: () => onPenaltyChanged(false),
          semanticLabel: 'Mark as penalty stroke',
        ),
        PenaltyToggle(
          label: 'Provisional',
          icon: Icons.refresh,
          state: isProvisional
              ? PenaltyToggleState.set
              : PenaltyToggleState.unset,
          onToggleOn: () => onProvisionalChanged(true),
          onToggleOff: () => onProvisionalChanged(false),
          semanticLabel: 'Mark as provisional ball',
        ),
        PenaltyToggle(
          label: 'Mulligan',
          icon: Icons.replay,
          state: isMulligan ? PenaltyToggleState.set : PenaltyToggleState.unset,
          onToggleOn: () => onMulliganChanged(true),
          onToggleOff: () => onMulliganChanged(false),
          semanticLabel: 'Mark as mulligan',
        ),
      ],
    );
  }
}
