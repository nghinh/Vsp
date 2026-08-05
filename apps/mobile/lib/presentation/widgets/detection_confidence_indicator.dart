// DetectionConfidenceIndicator — VSP Mobile App
//
// Story 6.2 — Wave F: Observability & Accessibility
//
// Non-color-only confidence indicator widget.
// Shows confidence level with icon + text + haptic feedback.
//
// Accessibility:
// - Non-color-only: uses icon, text, and color together
// - Screen reader compatible: semanticLabel on all icons
// - Haptic feedback on interaction
// - Supports large text and bold fonts per UX spec §10

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/course_hole_detection.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Non-color-only confidence indicator for hole detection.
///
/// Displays confidence level with icon + text + color.
/// Used in the hole map header to show detection quality.
///
/// Accessibility (per UX spec §10):
/// - Non-color-only: icon + text + color together
/// - Semantic labels for screen readers
/// - Haptic feedback on tap
class DetectionConfidenceIndicator extends StatelessWidget {
  /// Current confidence level.
  final ConfidenceLevel? level;

  /// Current confidence score (0.0-1.0).
  final double? confidence;

  /// Whether auto-switch is enabled.
  final bool canAutoSwitch;

  /// Callback when indicator is tapped.
  final VoidCallback? onTap;

  const DetectionConfidenceIndicator({
    super.key,
    this.level,
    this.confidence,
    this.canAutoSwitch = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Default to low if no level
    final currentLevel = level ?? ConfidenceLevel.low;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _backgroundColor(currentLevel, theme),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _foregroundColor(currentLevel, theme),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(currentLevel),
              size: 16,
              color: _foregroundColor(currentLevel, theme),
              semanticLabel: AppLocalizations.of(context).detectionConfidenceLabel(currentLevel.displayLabel),
            ),
            const SizedBox(width: 6),
            Text(
              currentLevel.displayLabel,
              style: TextStyle(
                color: _foregroundColor(currentLevel, theme),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            if (confidence != null) ...[
              const SizedBox(width: 4),
              Text(
                '${(confidence! * 100).round()}%',
                style: TextStyle(
                  color: _foregroundColor(currentLevel, theme).withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
            if (canAutoSwitch) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.auto_awesome,
                size: 12,
                color: _foregroundColor(currentLevel, theme),
                semanticLabel: AppLocalizations.of(context).detectionAutoSwitch,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _icon(ConfidenceLevel level) {
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

  Color _foregroundColor(ConfidenceLevel level, ThemeData theme) {
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

  Color _backgroundColor(ConfidenceLevel level, ThemeData theme) {
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

/// Detail dialog for confidence indicator.
class DetectionConfidenceDetailDialog extends StatelessWidget {
  final ConfidenceLevel level;
  final double confidence;
  final bool canAutoSwitch;
  final String? reason;

  const DetectionConfidenceDetailDialog({
    super.key,
    required this.level,
    required this.confidence,
    required this.canAutoSwitch,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(_icon(level), color: _foregroundColor(level, theme), size: 24),
          const SizedBox(width: 12),
          Text(AppLocalizations.of(context).detectionConfidenceTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('Level', level.displayLabel),
          _DetailRow('Score', '${(confidence * 100).round()}%'),
          _DetailRow('Auto-switch', canAutoSwitch ? 'Enabled' : 'Disabled'),
          if (reason != null) ...[
            const Divider(),
            _DetailRow('Reason', reason!),
          ],
          const SizedBox(height: 8),
          Text(
            _explainText(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonClose),
        ),
      ],
    );
  }

  IconData _icon(ConfidenceLevel level) {
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

  Color _foregroundColor(ConfidenceLevel level, ThemeData theme) {
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

  String _explainText() {
    switch (level) {
      case ConfidenceLevel.low:
        return 'Low confidence means the app is not sure which hole you are on. '
            'Please select your hole manually.';
      case ConfidenceLevel.medium:
        return 'Medium confidence means the app has a guess but is not certain. '
            'Auto-switch is disabled. You can still select your hole manually.';
      case ConfidenceLevel.high:
        return 'High confidence means the app is fairly sure which hole you are on. '
            'Auto-switch is enabled.';
      case ConfidenceLevel.veryHigh:
        return 'Very high confidence means the app is very sure. '
            'Auto-switch is enabled with a confirmation toast.';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
