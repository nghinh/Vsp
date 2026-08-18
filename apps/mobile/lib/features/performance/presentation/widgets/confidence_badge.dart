// ConfidenceBadge — VSP Mobile App
//
// Badge showing confidence level (insufficient/low/medium/high).
// Per Story 11.1 AC-1, AC-2 and Slice 3.
//
// Accessibility: uses icon + text + color, not color alone.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/performance/club_performance_stats.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Badge displaying the confidence level with icon and explanation text.
/// Per NFR-4: non-color-only indicators with icon + text.
class ConfidenceBadge extends StatelessWidget {
  final ConfidenceLevel level;
  final bool showExplanation;
  final bool compact;

  const ConfidenceBadge({
    super.key,
    required this.level,
    this.showExplanation = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = colorScheme.brightness;
    final isDark = brightness == Brightness.dark;

    final (icon, color, bgColor, labelText, description) = _styleFor(context);
    final iconWidget = Icon(icon, size: compact ? 14 : 16, color: color);

    if (compact) {
      return Semantics(
        label: AppLocalizations.of(context).performanceConfidence(labelText),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 4),
              Text(
                labelText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: AppLocalizations.of(context).performanceConfidenceDetail(labelText, description),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confidence: $labelText',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (showExplanation) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color, String, String) _styleFor(BuildContext context) {
    // Two of these are chart blues with no role in the scheme, and they do
    // keep a real light/dark pair. Read the brightness off the theme rather
    // than have every caller carry a flag beside the context it already has.
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    switch (level) {
      case ConfidenceLevel.insufficient:
        return (
          Icons.warning_amber_rounded,
          Theme.of(context).colorScheme.error,
          Theme.of(context).colorScheme.error,
          'Insufficient',
          'Not enough shots to provide reliable statistics.',
        );
      case ConfidenceLevel.low:
        return (
          Icons.info_outline,
          Theme.of(context).colorScheme.secondary,
          Theme.of(context).colorScheme.secondary,
          'Low',
          'Limited data — statistics may vary significantly.',
        );
      case ConfidenceLevel.medium:
        return (
          Icons.analytics_outlined,
          isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
          isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
          'Medium',
          'Moderate data — statistics are reasonably stable.',
        );
      case ConfidenceLevel.high:
        return (
          Icons.verified,
          isDark ? const Color(0xFF34D399) : Theme.of(context).colorScheme.tertiary,
          isDark ? const Color(0xFF34D399) : Theme.of(context).colorScheme.tertiary,
          'High',
          'Robust data — statistics are highly reliable.',
        );
    }
  }
}
