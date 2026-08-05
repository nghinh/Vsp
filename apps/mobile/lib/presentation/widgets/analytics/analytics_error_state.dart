// Analytics Error State — VSP Mobile App
//
// Error state for analytics screens with retry action.
// Per UX spec error/retry state requirements.

import 'package:flutter/material.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Error state shown when analytics loading fails.
class AnalyticsErrorState extends StatelessWidget {
  /// Error message to display.
  final String message;

  /// Optional retry callback.
  final VoidCallback? onRetry;

  const AnalyticsErrorState({super.key, required this.message, this.onRetry});

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
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
              semanticLabel: AppLocalizations.of(context).analyticsErrorLoading,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
