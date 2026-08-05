// WeatherErrorView — VSP Mobile App
//
// Story 7.1 Wave 3: Error State
// Per slice plan §3.4 — error state with retry button and reason text.

import 'package:flutter/material.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Error state view for weather panel.
///
/// Displays:
/// - Error icon
/// - Error message / reason
/// - Retry button (minimum 44pt touch target)
class WeatherErrorView extends StatelessWidget {
  /// Error code for logging/analytics.
  final String errorCode;

  /// Human-readable error message.
  final String message;

  /// Whether a retry is available (network error vs. permanent failure).
  final bool canRetry;

  /// Callback when retry is tapped.
  final VoidCallback? onRetry;

  const WeatherErrorView({
    super.key,
    required this.errorCode,
    required this.message,
    this.canRetry = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: AppLocalizations.of(context).weatherErrorLabel(context.tr(message)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Weather Unavailable',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(message),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (canRetry && onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).commonRetry),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
