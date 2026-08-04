// Progressive Score Field — VSP Mobile App
//
// Numeric stepper widget for putts and penalties progressive disclosure fields.
// Includes decrement/increment buttons with 44pt minimum touch targets.
//
// Animation: 150–200ms subtle expansion when revealed.
//
// Story 5.3 — Slice 4: Progressive Disclosure

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Minimum touch target size in logical pixels (44pt iOS / 48dp Android).
const double kMinTouchTarget = 44.0;

/// Animation duration for progressive field reveal.
const Duration kProgressiveAnimationDuration = Duration(milliseconds: 175);

/// Widget for entering putts or penalties via +/- stepper.
class ProgressiveScoreField extends StatelessWidget {
  /// Field type label for display.
  final String label;

  /// Current value (null if not set).
  final int? value;

  /// Callback when increment is pressed.
  final VoidCallback onIncrement;

  /// Callback when decrement is pressed.
  final VoidCallback onDecrement;

  /// Callback when field is cleared (value set to null).
  final VoidCallback? onClear;

  /// Semantic label for accessibility.
  final String semanticLabel;

  const ProgressiveScoreField({
    super.key,
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    this.onClear,
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
          // Field label
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Decrement button
          _StepperButton(
            icon: Icons.remove,
            onPressed: onDecrement,
            semanticLabel: 'Decrease $label',
          ),

          const SizedBox(width: 4),

          // Value display
          GestureDetector(
            onTap: onClear,
            child: Container(
              constraints: const BoxConstraints(minWidth: 32),
              alignment: Alignment.center,
              child: Text(
                value?.toString() ?? '—',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: value != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Increment button
          _StepperButton(
            icon: Icons.add,
            onPressed: onIncrement,
            semanticLabel: 'Increase $label',
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: kMinTouchTarget,
            height: kMinTouchTarget,
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated container that reveals child content with a subtle slide + fade.
class ProgressiveReveal extends StatelessWidget {
  /// Whether the content should be visible.
  final bool isExpanded;

  /// The child widget to reveal.
  final Widget child;

  const ProgressiveReveal({
    super.key,
    required this.isExpanded,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: kProgressiveAnimationDuration,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: kProgressiveAnimationDuration,
        opacity: isExpanded ? 1.0 : 0.0,
        child: isExpanded ? child : const SizedBox.shrink(),
      ),
    );
  }
}
