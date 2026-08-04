// Hole Navigation Bar — VSP Mobile App
//
// Bottom navigation bar for moving between holes.
// Shows Prev/Next hole buttons and progress indicator.
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:flutter/material.dart';

/// Bottom navigation bar for hole-to-hole navigation.
class HoleNavigationBar extends StatelessWidget {
  /// Current hole index (0-based).
  final int currentHoleIndex;

  /// Total number of holes.
  final int totalHoles;

  /// Callback for navigating to previous hole.
  final VoidCallback onPrevious;

  /// Callback for navigating to next hole.
  final VoidCallback onNext;

  /// Callback for completing the round.
  final VoidCallback? onCompleteRound;

  /// Minimum touch target size.
  static const double kMinTouchTarget = 44.0;

  const HoleNavigationBar({
    super.key,
    required this.currentHoleIndex,
    required this.totalHoles,
    required this.onPrevious,
    required this.onNext,
    this.onCompleteRound,
  });

  bool get canGoBack => currentHoleIndex > 0;
  bool get canGoForward => currentHoleIndex < totalHoles - 1;
  bool get isLastHole => currentHoleIndex == totalHoles - 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Previous hole button
          _buildNavButton(
            context: context,
            icon: Icons.chevron_left,
            label: 'Prev Hole',
            onPressed: canGoBack ? onPrevious : null,
          ),

          const SizedBox(width: 8),

          // Hole progress
          Expanded(
            child: Semantics(
              label: 'Hole ${currentHoleIndex + 1} of $totalHoles',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hole ${currentHoleIndex + 1} of $totalHoles',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (currentHoleIndex + 1) / totalHoles,
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.15,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Next hole or Complete Round button
          if (isLastHole && onCompleteRound != null)
            _buildCompleteButton(context)
          else
            _buildNavButton(
              context: context,
              icon: Icons.chevron_right,
              label: 'Next Hole',
              onPressed: canGoForward ? onNext : null,
            ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;

    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: kMinTouchTarget,
            height: kMinTouchTarget,
            child: Icon(
              icon,
              color: enabled
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Complete Round',
      button: true,
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onCompleteRound,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: kMinTouchTarget,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              'Complete Round',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
