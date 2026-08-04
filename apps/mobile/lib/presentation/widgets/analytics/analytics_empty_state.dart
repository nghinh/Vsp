// Analytics Empty State — VSP Mobile App
//
// Empty state for analytics screens with actionable guidance.
// Per UX spec empty state requirements.

import 'package:flutter/material.dart';

/// Empty state shown when no analytics data is available.
class AnalyticsEmptyState extends StatelessWidget {
  /// Primary message to display.
  final String title;

  /// Detailed explanation.
  final String? subtitle;

  /// Action button label (e.g., "Record Shots").
  final String? actionLabel;

  /// Callback when action button is pressed.
  final VoidCallback? onAction;

  const AnalyticsEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: colorScheme.outline,
              semanticLabel: 'No analytics data',
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
