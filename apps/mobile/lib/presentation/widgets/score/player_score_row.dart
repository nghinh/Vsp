// Player Score Row — VSP Mobile App
//
// Per-player score row widget with score indicator and +/- buttons.
// Two-tap flow: tap row to show controls (if not expanded), then tap +/-.
// Score indicator uses shapes + text (non-color-only per AC-3).
//
// Touch targets: all buttons ≥44×44pt (iOS) / 48×48dp (Android).
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:flutter/material.dart';

/// Score entry state for a single player on a single hole.
enum PlayerScoreStatus {
  /// Score has been entered (filled circle).
  entered,

  /// Score not yet entered (empty circle).
  notEntered,

  /// Hole not applicable / not played (dash).
  notPlayed,
}

/// Widget representing a single player's score row.
class PlayerScoreRow extends StatelessWidget {
  /// Player display name.
  final String playerName;

  /// Current gross score (null if not entered).
  final int? grossScore;

  /// Score entry status.
  final PlayerScoreStatus status;

  /// Callback when increment button is pressed.
  final VoidCallback onIncrement;

  /// Callback when decrement button is pressed.
  final VoidCallback onDecrement;

  /// Callback when score number is tapped (for direct numeric entry).
  final VoidCallback onScoreTap;

  /// Whether this row is currently expanded (showing controls).
  final bool isExpanded;

  /// Minimum touch target size in logical pixels (44pt iOS / 48dp Android).
  static const double kMinTouchTarget = 44.0;

  const PlayerScoreRow({
    super.key,
    required this.playerName,
    this.grossScore,
    this.status = PlayerScoreStatus.notEntered,
    required this.onIncrement,
    required this.onDecrement,
    required this.onScoreTap,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: _semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
          ),
        ),
        child: Row(
          children: [
            // Score status indicator (shapes + number — non-color-only)
            _buildScoreIndicator(theme),

            const SizedBox(width: 12),

            // Player name
            Expanded(
              flex: 2,
              child: Text(
                playerName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Score controls (shown when expanded or has score)
            if (isExpanded || status == PlayerScoreStatus.entered) ...[
              // Decrement button
              _buildScoreButton(
                icon: Icons.remove,
                onPressed: onDecrement,
                semanticLabel: 'Decrease score for $playerName',
                theme: theme,
              ),

              // Score display / tap target
              _buildScoreDisplay(theme),

              // Increment button
              _buildScoreButton(
                icon: Icons.add,
                onPressed: onIncrement,
                semanticLabel: 'Increase score for $playerName',
                theme: theme,
              ),
            ] else
              // Placeholder when not expanded
              Text(
                'Tap to enter',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(ThemeData theme) {
    final (icon, label) = switch (status) {
      PlayerScoreStatus.entered => ('●', 'Score entered: ${grossScore ?? ""}'),
      PlayerScoreStatus.notEntered => ('○', 'Score not entered'),
      PlayerScoreStatus.notPlayed => ('—', 'Hole not played'),
    };

    return Semantics(
      label: label,
      child: SizedBox(
        width: 32,
        child: Text(
          icon,
          style: TextStyle(
            fontSize: 18,
            color: status == PlayerScoreStatus.entered
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildScoreDisplay(ThemeData theme) {
    return GestureDetector(
      onTap: onScoreTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: kMinTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              grossScore?.toString() ?? '—',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: grossScore != null
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            Text(
              'gross',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String semanticLabel,
    required ThemeData theme,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: kMinTouchTarget,
            height: kMinTouchTarget,
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }

  String get _semanticLabel {
    return switch (status) {
      PlayerScoreStatus.entered => '$playerName, score ${grossScore ?? ""}',
      PlayerScoreStatus.notEntered => '$playerName, score not entered',
      PlayerScoreStatus.notPlayed => '$playerName, hole not played',
    };
  }
}
