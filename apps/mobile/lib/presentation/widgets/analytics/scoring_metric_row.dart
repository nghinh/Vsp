// Scoring Metric Row — VSP Mobile App
//
// Reusable row widget for displaying a scoring metric.
// Per Story 11.2 AC2: scoring metric display.

import 'package:flutter/material.dart';

/// A single row displaying a scoring metric with label and value.
class ScoringMetricRow extends StatelessWidget {
  /// Metric display label.
  final String label;

  /// Metric value (e.g., "3", "71.2", "+2").
  final String value;

  /// Optional sub-label (e.g., "putts", "yards").
  final String? subLabel;

  /// Icon to display next to the label.
  final IconData? icon;

  /// Whether the metric value should be highlighted (e.g., eagle/birdie).
  final bool highlighted;

  const ScoringMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.subLabel,
    this.icon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: highlighted ? Theme.of(context).colorScheme.tertiary : colorScheme.onSurface,
                ),
              ),
              if (subLabel != null)
                Text(
                  subLabel!,
                  style: TextStyle(fontSize: 11, color: colorScheme.outline),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
