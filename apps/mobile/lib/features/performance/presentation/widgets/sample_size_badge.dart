// SampleSizeBadge — VSP Mobile App
//
// Badge showing sample size label (insufficient/limited/moderate/robust).
// Per Story 11.1 AC-2 and Slice 3.
//
// Accessibility: includes semantic label for screen readers.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/performance/club_performance_stats.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Badge displaying the sample size label with appropriate color coding.
class SampleSizeBadge extends StatelessWidget {
  final SampleSizeLabel label;
  final int sampleSize;
  final bool showCount;

  const SampleSizeBadge({
    super.key,
    required this.label,
    required this.sampleSize,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, labelText) = _badgeStyle(context);

    return Semantics(
      label: AppLocalizations.of(context).performanceSampleSize('$sampleSize', labelText),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(label), size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              showCount
                  ? AppLocalizations.of(context)
                      .performanceShotsCount('$sampleSize')
                  : labelText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, String) _badgeStyle(BuildContext context) {
    final brightness = Theme.of(context).colorScheme.brightness;
    final isDark = brightness == Brightness.dark;

    switch (label) {
      case SampleSizeLabel.insufficient:
        return (
          isDark ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.error, // Red
          isDark ? const Color(0x1AF87171) : const Color(0x1ADC2626),
          'Insufficient',
        );
      case SampleSizeLabel.limited:
        return (
          isDark
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.primary, // Amber/Orange
          isDark ? const Color(0x1AFBBF24) : const Color(0x1AF97316),
          'Limited',
        );
      case SampleSizeLabel.moderate:
        return (
          isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6), // Blue
          isDark ? const Color(0x1A60A5FA) : const Color(0x1A3B82F6),
          'Moderate',
        );
      case SampleSizeLabel.robust:
        return (
          isDark ? const Color(0xFF34D399) : Theme.of(context).colorScheme.tertiary, // Green
          isDark ? const Color(0x1A34D399) : const Color(0x1A059669),
          'Robust',
        );
    }
  }

  IconData _iconFor(SampleSizeLabel label) {
    switch (label) {
      case SampleSizeLabel.insufficient:
        return Icons.warning_amber_rounded;
      case SampleSizeLabel.limited:
        return Icons.info_outline;
      case SampleSizeLabel.moderate:
        return Icons.check_circle_outline;
      case SampleSizeLabel.robust:
        return Icons.verified;
    }
  }
}
