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
import 'package:vsp_mobile/l10n/app_localizations.dart';

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

  /// Whether the one-tap score strip is offered under this row.
  ///
  /// True hides the +/- steppers: they would be a second control for a number
  /// the strip already sets in one tap. False — a hole with no par on file —
  /// keeps them, because then the strip cannot exist and the alternative is
  /// the keyboard.
  final bool hasQuickScores;

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
    this.hasQuickScores = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: _semanticLabel(AppLocalizations.of(context)),
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
            _buildScoreIndicator(context, theme),

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

            // The steppers, only where nothing better is offered.
            //
            // Two controls for one number is the definition of the clutter
            // this screen was reported for. Where the hole's par is known the
            // strip below this row sets any score in one tap — including
            // changing one, since the current entry is shown selected — so
            // +/- adds a second way to do the same thing and nothing else.
            //
            // Where par is unknown the strip cannot be built ("one under
            // what?"), and then the steppers are the only thing standing
            // between the golfer and the keyboard. They stay for that case.
            if (isExpanded || status == PlayerScoreStatus.entered) ...[
              if (!hasQuickScores)
                _buildScoreButton(
                  icon: Icons.remove,
                  onPressed: onDecrement,
                  semanticLabel: AppLocalizations.of(
                    context,
                  ).scoreDecreaseFor(playerName),
                  theme: theme,
                ),

              // Score display / tap target
              _buildScoreDisplay(context, theme),

              if (!hasQuickScores)
                _buildScoreButton(
                  icon: Icons.add,
                  onPressed: onIncrement,
                  semanticLabel: AppLocalizations.of(
                    context,
                  ).scoreIncreaseFor(playerName),
                  theme: theme,
                ),
            ] else
              // Placeholder when not expanded
              Text(
                AppLocalizations.of(context).scorecardTapToEnter,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(BuildContext context, ThemeData theme) {
    final (icon, label) = switch (status) {
      PlayerScoreStatus.entered => (
        '●',
        AppLocalizations.of(context).scoreEnteredValue('${grossScore ?? ""}'),
      ),
      PlayerScoreStatus.notEntered => (
        '○',
        AppLocalizations.of(context).scorecardScoreNotEntered,
      ),
      PlayerScoreStatus.notPlayed => (
        '—',
        AppLocalizations.of(context).scorecardHoleNotPlayed,
      ),
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

  Widget _buildScoreDisplay(BuildContext context, ThemeData theme) {
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
              // Was the literal 'gross' — English, on a Vietnamese screen,
              // under every score in the flight.
              AppLocalizations.of(context).scoreGrossLabel,
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

  /// What a screen reader announces for this row.
  ///
  /// Localised like everything else: a golfer using TalkBack in Vietnamese was
  /// hearing "score not entered" between two Vietnamese sentences.
  String _semanticLabel(AppLocalizations l10n) {
    return switch (status) {
      PlayerScoreStatus.entered => l10n.scoreRowEntered(
        playerName,
        '${grossScore ?? ""}',
      ),
      PlayerScoreStatus.notEntered => l10n.scoreRowNotEntered(playerName),
      PlayerScoreStatus.notPlayed => l10n.scoreRowNotPlayed(playerName),
    };
  }
}
