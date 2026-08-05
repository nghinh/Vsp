// Distance Value Display — VSP Mobile App
//
// Story 6.4 — Wave 3: UI Components
// UX spec §6.1: Large typography for front/center/back distances
// UX spec §10: Accessibility — semantics labels, large text support, 44pt touch targets
//
// Reusable large numeric display for a single distance value.
// Displays value in selected unit (meters/yards) with label and confidence indicator.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../domain/value_objects/distance_measurement.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A single distance value display with large typography.
///
/// Shows a distance value prominently with:
/// - Large numeric display (configurable size)
/// - Unit label (m/yd)
/// - Short label (Front/Center/Back/Pin)
/// - Confidence indicator (text + color, not color-only per AC)
/// - Source badge (Official/Estimated) — optional
///
/// Accessibility:
/// - Semantics label for screen readers
/// - Supports text scaling (large text mode)
/// - Excludes from Semantics only when [excludeFromSemantics] is true
class DistanceValueDisplay extends StatelessWidget {
  /// The distance measurement to display.
  final DistanceMeasurement measurement;

  /// Display unit — overrides measurement's unit preference.
  final bool useYards;

  /// Label shown above the numeric value.
  final String? label;

  /// Font size for the numeric value. Default 36.
  final double fontSize;

  /// True to show the source badge (official/estimated).
  final bool showSource;

  /// True to show the confidence indicator.
  final bool showConfidence;

  /// True to exclude this widget from semantics (use when wrapped by parent).
  final bool excludeFromSemantics;

  const DistanceValueDisplay({
    super.key,
    required this.measurement,
    this.useYards = false,
    this.label,
    this.fontSize = 36,
    this.showSource = false,
    this.showConfidence = true,
    this.excludeFromSemantics = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayValue = measurement.displayValue(useYards: useYards);
    final unitLabel = measurement.unitLabel(useYards: useYards);
    final formattedValue = displayValue.round().toString();
    final confidenceColor = _confidenceColor(measurement.confidenceLevel);
    final confidenceLabel = _confidenceLabel(measurement.confidenceLevel);

    final widget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Label
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),

        // Main numeric value
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Semantics(
              label:
                  '${measurement.type.shortLabel}: $formattedValue $unitLabel',
              child: Text(
                formattedValue,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  // Use Fira Code for numeric precision
                  fontFamily: 'monospace',
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unitLabel,
                style: TextStyle(
                  fontSize: fontSize * 0.35,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),

        // Confidence + source row
        if (showConfidence || showSource) const SizedBox(height: 2),
        if (showConfidence || showSource)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showConfidence)
                _ConfidenceBadge(
                  level: measurement.confidenceLevel,
                  color: confidenceColor,
                  label: confidenceLabel,
                ),
              if (showConfidence && showSource) const SizedBox(width: 4),
              if (showSource) _SourceBadge(source: measurement.source),
            ],
          ),
      ],
    );

    if (excludeFromSemantics) {
      return ExcludeSemantics(child: widget);
    }
    return widget;
  }

  static Color _confidenceColor(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.high:
        return const Color(0xFF059669); // green
      case ConfidenceLevel.medium:
        return const Color(0xFFF97316); // amber
      case ConfidenceLevel.low:
        return const Color(0xFFEA580C); // orange
      case ConfidenceLevel.veryLow:
        return const Color(0xFFDC2626); // red
    }
  }

  static String _confidenceLabel(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.high:
        return 'High';
      case ConfidenceLevel.medium:
        return 'Med';
      case ConfidenceLevel.low:
        return 'Low';
      case ConfidenceLevel.veryLow:
        return 'VLow';
    }
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final ConfidenceLevel level;
  final Color color;
  final String label;

  const _ConfidenceBadge({
    required this.level,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).distanceConfidenceLabel(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final DistanceSource source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isOfficial = source == DistanceSource.official;
    final color = isOfficial
        ? const Color(0xFF059669)
        : const Color(0xFFF97316);

    return Semantics(
      label: AppLocalizations.of(context).distanceSourceLabel(source.displayName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Text(
          source.displayName,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
