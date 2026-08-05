// Empty Search State — VSP Mobile App
//
// Empty state widget for course search — shown when no results are found.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Empty state for course search — shown when search returns no results.
class EmptySearchState extends StatelessWidget {
  /// Message to display. When null the [variant] supplies a localized default.
  final String? message;

  /// Optional subtitle for additional context.
  final String? subtitle;

  /// Icon to show — defaults to search icon.
  final IconData icon;

  /// Action button to show (optional).
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Which preset this state represents — decides the localized copy when
  /// [message]/[subtitle]/[actionLabel] are not given explicitly.
  final EmptySearchVariant variant;

  const EmptySearchState({
    super.key,
    this.message,
    this.subtitle,
    this.icon = Icons.search_off,
    this.actionLabel,
    this.onAction,
  }) : variant = EmptySearchVariant.custom;

  /// Empty state for no search results.
  const EmptySearchState.noResults({
    super.key,
    this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.golf_course,
       variant = EmptySearchVariant.noResults;

  /// Empty state for no favorites.
  const EmptySearchState.noFavorites({
    super.key,
    this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.favorite_border,
       variant = EmptySearchVariant.noFavorites;

  /// Empty state for no recent courses.
  const EmptySearchState.noRecent({
    super.key,
    this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.history,
       variant = EmptySearchVariant.noRecent;

  /// Empty state for location permission denied.
  const EmptySearchState.locationDenied({
    super.key,
    this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.location_off,
       variant = EmptySearchVariant.locationDenied;

  /// Empty state for offline with no cached results.
  const EmptySearchState.offline({
    super.key,
    this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.wifi_off,
       variant = EmptySearchVariant.offline;

  ({String message, String? subtitle, String? action}) _copy(
    AppLocalizations l10n,
  ) => switch (variant) {
    EmptySearchVariant.noResults => (
      message: l10n.courseSearchNoResults,
      subtitle: l10n.courseSearchNoResultsSubtitle,
      action: null,
    ),
    EmptySearchVariant.noFavorites => (
      message: l10n.courseFavoritesEmpty,
      subtitle: l10n.courseFavoritesEmptySubtitle,
      action: null,
    ),
    EmptySearchVariant.noRecent => (
      message: l10n.courseRecentEmpty,
      subtitle: l10n.courseRecentEmptySubtitle,
      action: null,
    ),
    EmptySearchVariant.locationDenied => (
      message: l10n.courseLocationUnavailable,
      subtitle: l10n.courseLocationUnavailableSubtitle,
      action: l10n.courseEnableLocation,
    ),
    EmptySearchVariant.offline => (
      message: l10n.courseOfflineTitle,
      subtitle: l10n.courseOfflineSubtitle,
      action: l10n.commonRetry,
    ),
    EmptySearchVariant.custom => (
      message: l10n.courseSearchNoResults,
      subtitle: null,
      action: null,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final copy = _copy(AppLocalizations.of(context));
    final resolvedMessage = message ?? copy.message;
    final resolvedSubtitle = subtitle ?? copy.subtitle;
    final resolvedAction = actionLabel ?? copy.action;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: VspIconSize.xl,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: VspSpacing.md),

            // Title
            Text(
              resolvedMessage,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (resolvedSubtitle != null) ...[
              const SizedBox(height: VspSpacing.xs),
              Text(
                resolvedSubtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Action button
            if (resolvedAction != null && onAction != null) ...[
              const SizedBox(height: VspSpacing.lg),
              VspButton(
                label: resolvedAction!,
                onPressed: onAction,
                variant: VspButtonVariant.secondary,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Presets for [EmptySearchState]; each maps to a localized message set.
enum EmptySearchVariant {
  custom,
  noResults,
  noFavorites,
  noRecent,
  locationDenied,
  offline,
}
