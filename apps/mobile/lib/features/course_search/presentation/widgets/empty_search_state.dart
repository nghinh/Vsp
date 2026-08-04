// Empty Search State — VSP Mobile App
//
// Empty state widget for course search — shown when no results are found.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

/// Empty state for course search — shown when search returns no results.
class EmptySearchState extends StatelessWidget {
  /// Message to display.
  final String message;

  /// Optional subtitle for additional context.
  final String? subtitle;

  /// Icon to show — defaults to search icon.
  final IconData icon;

  /// Action button to show (optional).
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptySearchState({
    super.key,
    required this.message,
    this.subtitle,
    this.icon = Icons.search_off,
    this.actionLabel,
    this.onAction,
  });

  /// Empty state for no search results.
  const EmptySearchState.noResults({
    super.key,
    this.message = 'No courses found',
    this.subtitle = 'Try adjusting your search or filters',
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.golf_course;

  /// Empty state for no favorites.
  const EmptySearchState.noFavorites({
    super.key,
    this.message = 'No Favorites Yet',
    this.subtitle = 'Courses you favorite will appear here',
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.favorite_border;

  /// Empty state for no recent courses.
  const EmptySearchState.noRecent({
    super.key,
    this.message = 'No Recent Courses',
    this.subtitle = 'Courses you view will appear here',
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.history;

  /// Empty state for location permission denied.
  const EmptySearchState.locationDenied({
    super.key,
    this.message = 'Location Unavailable',
    this.subtitle = 'Enable location to find nearby courses',
    this.actionLabel = 'Enable Location',
    this.onAction,
  }) : icon = Icons.location_off;

  /// Empty state for offline with no cached results.
  const EmptySearchState.offline({
    super.key,
    this.message = 'You\'re Offline',
    this.subtitle = 'Connect to the internet to search for courses',
    this.actionLabel = 'Retry',
    this.onAction,
  }) : icon = Icons.wifi_off;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: VspSpacing.xs),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: VspSpacing.lg),
              VspButton(
                label: actionLabel!,
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
