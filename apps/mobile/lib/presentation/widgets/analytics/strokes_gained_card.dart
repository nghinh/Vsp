// Strokes Gained Card Widget — VSP Mobile App
//
// Displays a single Strokes Gained result with category, benchmark comparison,
// sample count, confidence, and limitation badges.
//
// Features:
//  - SG value with sign coloring (green = positive, red = negative)
//  - Baseline vs actual strokes display
//  - Sample count indicator
//  - Confidence meter
//  - Limitation badge when limitation != null
//  - Accessibility: screen reader labels, icons + text (non-color-only)
//
// Touch targets ≥ 44pt per UX requirements.
//
// Story 11.3 — Slice 3: UI Shell

import 'package:flutter/material.dart';

import '../../../domain/models/strokes_gained.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A card widget displaying Strokes Gained result for a single category.
class StrokesGainedCard extends StatelessWidget {
  /// The Strokes Gained result to display.
  final StrokesGainedResult result;

  /// Called when the card is tapped (optional).
  final VoidCallback? onTap;

  const StrokesGainedCard({super.key, required this.result, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLimitation = result.limitation != null;

    return Semantics(
      label: _accessibilityLabel(),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: category name + SG value
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        result.category.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _StrokesGainedValue(result: result),
                  ],
                ),

                const SizedBox(height: 12),

                // Baseline vs Actual row
                _BaselineActualRow(result: result),

                const SizedBox(height: 12),

                // Sample count + Confidence row
                Row(
                  children: [
                    _SampleCountBadge(sampleCount: result.sampleCount),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ConfidenceMeter(confidence: result.confidence),
                    ),
                  ],
                ),

                // Limitation badge
                if (hasLimitation) ...[
                  const SizedBox(height: 8),
                  _LimitationBadge(limitation: result.limitation!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _accessibilityLabel() {
    final sg = result.strokesGained;
    final sign = sg >= 0 ? 'gained' : 'lost';
    final absSg = sg.abs();
    final limitationText = result.limitation != null
        ? ', ${result.limitation!.displayName}'
        : '';

    return '${result.category.displayName}: $absSg strokes $sign, '
        '${result.sampleCount} samples, '
        '${(result.confidence * 100).round()}% confidence'
        '$limitationText';
  }
}

/// Displays the strokes gained value with sign coloring.
class _StrokesGainedValue extends StatelessWidget {
  final StrokesGainedResult result;

  const _StrokesGainedValue({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sg = result.strokesGained;
    final isPositive = sg >= 0;
    final absSg = sg.abs();

    // Color coding: green for positive (gained), red for negative (lost)
    final color = result.hasLimitation
        ? theme.colorScheme.onSurfaceVariant
        : (isPositive
              ? const Color(0xFF2E7D32) // green-800
              : const Color(0xFFC62828)); // red-800

    final icon = result.hasLimitation
        ? Icons.warning_amber_rounded
        : (isPositive ? Icons.arrow_upward : Icons.arrow_downward);

    // Accessibility: icon + text (non-color-only)
    final iconLabel = result.hasLimitation
        ? 'warning'
        : (isPositive ? 'strokes gained' : 'strokes lost');

    return Semantics(
      label: '${absSg.toStringAsFixed(1)} strokes $iconLabel',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20, semanticLabel: iconLabel),
          const SizedBox(width: 4),
          Text(
            '${isPositive ? '+' : '-'}${absSg.toStringAsFixed(1)}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays baseline vs actual strokes.
class _BaselineActualRow extends StatelessWidget {
  final StrokesGainedResult result;

  const _BaselineActualRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInsufficient = result.isSampleInsufficient;

    return Row(
      children: [
        // Baseline
        Expanded(
          child: _StatTile(
            label: AppLocalizations.of(context).analyticsBenchmark,
            value: isInsufficient
                ? '—'
                : result.baselineStrokes.toStringAsFixed(1),
            icon: Icons.flag_outlined,
          ),
        ),
        const SizedBox(width: 8),
        // Arrow
        Icon(
          Icons.arrow_forward,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
          semanticLabel: 'compared to',
        ),
        const SizedBox(width: 8),
        // Actual
        Expanded(
          child: _StatTile(
            label: AppLocalizations.of(context).analyticsActual,
            value: isInsufficient
                ? '—'
                : result.actualStrokes.toStringAsFixed(1),
            icon: Icons.golf_course_outlined,
          ),
        ),
      ],
    );
  }
}

/// A small stat tile with icon + label + value.
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
            semanticLabel: label,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sample count badge with icon.
class _SampleCountBadge extends StatelessWidget {
  final int sampleCount;

  const _SampleCountBadge({required this.sampleCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInsufficient = sampleCount < 20;

    return Semantics(
      label:
          '$sampleCount samples, ${isInsufficient ? "insufficient" : "sufficient"}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isInsufficient
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart,
              size: 14,
              color: isInsufficient
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onPrimaryContainer,
              semanticLabel: 'sample count',
            ),
            const SizedBox(width: 4),
            Text(
              '$sampleCount',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isInsufficient
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confidence meter bar.
class _ConfidenceMeter extends StatelessWidget {
  final double confidence;

  const _ConfidenceMeter({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidencePercent = (confidence * 100).round();

    // Color gradient from red (low) to green (high)
    Color barColor;
    if (confidence < 0.4) {
      barColor = theme.colorScheme.error;
    } else if (confidence < 0.7) {
      barColor = const Color(0xFFFF8F00); // amber-800
    } else {
      barColor = const Color(0xFF2E7D32); // green-800
    }

    return Semantics(
      label: '$confidencePercent% confidence',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).strokesGainedConfidence,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$confidencePercent%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Limitation warning badge.
class _LimitationBadge extends StatelessWidget {
  final SGLimitation limitation;

  const _LimitationBadge({required this.limitation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: AppLocalizations.of(context).analyticsLimitation(limitation.displayName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onTertiaryContainer,
              semanticLabel: 'limitation',
            ),
            const SizedBox(width: 4),
            Text(
              limitation.displayName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
