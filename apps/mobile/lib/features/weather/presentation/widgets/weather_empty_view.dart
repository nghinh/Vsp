// WeatherEmptyView — VSP Mobile App
//
// Story 7.1 Wave 3: Empty State
// Per slice plan §3.4 — "Weather unavailable" with retry.

import 'package:flutter/material.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Empty state view for weather panel.
///
/// Displayed when no weather data is available (not yet loaded, cleared, etc.).
class WeatherEmptyView extends StatelessWidget {
  /// Callback when retry is tapped.
  final VoidCallback? onRetry;

  const WeatherEmptyView({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: AppLocalizations.of(context).weatherUnavailable,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).weatherUnavailable,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).weatherUnavailableBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).commonRetry),
                style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
