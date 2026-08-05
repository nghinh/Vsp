// HoleSwitchConfirmationDialog — VSP Mobile App
//
// Confirmation dialog shown when auto-switch is blocked due to low confidence
// but the user may still manually confirm the suggested hole switch.
//
// Accessibility:
// - Minimum 44pt touch targets (iOS HIG)
// - Non-color-only indication (uses icon + text + vibration)
// - Screen reader compatible (semantic labels)
// - Supports large text and bold fonts
//
// Story 6.2 — Wave D: Manual Override & Audit

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/course_hole_detection.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Dialog shown when hole auto-switch is blocked but user can confirm manually.
///
/// Triggered when:
/// - Detection confidence is medium (0.4-0.6) - suggestion shown
/// - User manually initiates a hole switch
///
/// Uses haptic feedback and visual indicators for accessibility.
class HoleSwitchConfirmationDialog extends StatelessWidget {
  /// The detected hole that would be selected.
  final int suggestedHoleNumber;

  /// Current hole number before switch.
  final int currentHoleNumber;

  /// Confidence level of the detection.
  final ConfidenceLevel confidenceLevel;

  /// Human-readable description of why auto-switch was blocked.
  final String blockedReason;

  /// Callback when user confirms the switch.
  final VoidCallback onConfirm;

  /// Callback when user cancels the switch.
  final VoidCallback onCancel;

  const HoleSwitchConfirmationDialog({
    super.key,
    required this.suggestedHoleNumber,
    required this.currentHoleNumber,
    required this.confidenceLevel,
    required this.blockedReason,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Show the dialog and return true if user confirmed.
  static Future<bool> show({
    required BuildContext context,
    required int suggestedHoleNumber,
    required int currentHoleNumber,
    required ConfidenceLevel confidenceLevel,
    required String blockedReason,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HoleSwitchConfirmationDialog(
        suggestedHoleNumber: suggestedHoleNumber,
        currentHoleNumber: currentHoleNumber,
        confidenceLevel: confidenceLevel,
        blockedReason: blockedReason,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _confidenceIcon(confidenceLevel),
            color: _confidenceColor(confidenceLevel, theme),
            size: 28,
            semanticLabel: AppLocalizations.of(context).holeSwitchConfidence(confidenceLevel.displayLabel),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Switch to Hole $suggestedHoleNumber?',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence indicator (non-color-only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _confidenceBackgroundColor(confidenceLevel, theme),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _confidenceIcon(confidenceLevel),
                  color: _confidenceColor(confidenceLevel, theme),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${confidenceLevel.displayLabel} — $blockedReason',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _confidenceColor(confidenceLevel, theme),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Current vs suggested hole
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HoleIndicator(
                label: AppLocalizations.of(context).holeSwitchCurrent,
                holeNumber: currentHoleNumber,
                isCurrent: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.arrow_forward,
                  color: theme.colorScheme.outline,
                  size: 24,
                  semanticLabel: AppLocalizations.of(context).holeSwitchSwitchingTo,
                ),
              ),
              _HoleIndicator(
                label: AppLocalizations.of(context).holeSwitchSuggested,
                holeNumber: suggestedHoleNumber,
                isCurrent: false,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Instruction text
          Text(
            'Tap Confirm to switch holes, or Cancel to stay on the current hole.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        // Cancel button - minimum 44pt touch target
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onCancel();
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),

        // Confirm button - minimum 44pt touch target
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onConfirm();
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }

  IconData _confidenceIcon(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.low:
        return Icons.error_outline;
      case ConfidenceLevel.medium:
        return Icons.warning_amber_rounded;
      case ConfidenceLevel.high:
        return Icons.check_circle_outline;
      case ConfidenceLevel.veryHigh:
        return Icons.check_circle;
    }
  }

  Color _confidenceColor(ConfidenceLevel level, ThemeData theme) {
    switch (level) {
      case ConfidenceLevel.low:
        return theme.colorScheme.error;
      case ConfidenceLevel.medium:
        return Colors.orange;
      case ConfidenceLevel.high:
        return Colors.green;
      case ConfidenceLevel.veryHigh:
        return Colors.green;
    }
  }

  Color _confidenceBackgroundColor(ConfidenceLevel level, ThemeData theme) {
    switch (level) {
      case ConfidenceLevel.low:
        return theme.colorScheme.errorContainer;
      case ConfidenceLevel.medium:
        return Colors.orange.withOpacity(0.15);
      case ConfidenceLevel.high:
        return Colors.green.withOpacity(0.15);
      case ConfidenceLevel.veryHigh:
        return Colors.green.withOpacity(0.15);
    }
  }
}

/// Widget showing a hole number with label.
class _HoleIndicator extends StatelessWidget {
  final String label;
  final int holeNumber;
  final bool isCurrent;

  const _HoleIndicator({
    required this.label,
    required this.holeNumber,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primaryContainer,
            border: Border.all(
              color: isCurrent
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            holeNumber.toString(),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isCurrent
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
