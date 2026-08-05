// Player Card — VSP Mobile App
//
// Card showing a player in the round setup.
// Displays player name, handicap, and primary badge.
// Supports remove action for non-primary players.
//
// Design: ux-spec §4, §5.2 — 44pt touch targets, accessible labels.
//
// Story 5.1 — Slice B: Round Setup UI Screen

import 'package:flutter/material.dart';

import '../../../../domain/models/player.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Card displaying a player in the round setup.
class PlayerCard extends StatelessWidget {
  final Player player;
  final bool canRemove;
  final VoidCallback? onRemove;

  const PlayerCard({
    super.key,
    required this.player,
    this.canRemove = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: player.isPrimary
          ? '${player.name}, primary player'
          : '${player.name}, ${player.handicap != null ? 'handicap ${player.handicap}' : 'no handicap'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: player.isPrimary
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Avatar / initials
            CircleAvatar(
              radius: 20,
              backgroundColor: player.isPrimary
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              child: Text(
                _getInitials(player.name),
                style: TextStyle(
                  color: player.isPrimary
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name and handicap
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        player.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (player.isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(context).roundSetupYou,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (player.handicap != null)
                    Text(
                      AppLocalizations.of(context).roundSetupPlayerHandicap(player.handicap!.toStringAsFixed(1)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            // Remove button (not for primary player)
            if (canRemove && !player.isPrimary && onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
                iconSize: 20,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44), // 44pt touch target
                  foregroundColor: colorScheme.error,
                ),
                tooltip: AppLocalizations.of(context).roundSetupRemovePlayer(player.name),
              ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}

/// Empty state for adding a player.
class AddPlayerCard extends StatelessWidget {
  final bool canAdd;
  final VoidCallback? onAdd;

  const AddPlayerCard({super.key, this.canAdd = true, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: canAdd ? AppLocalizations.of(context).roundSetupAddPlayerHint : AppLocalizations.of(context).roundSetupMaxPlayers,
      button: true,
      child: InkWell(
        onTap: canAdd ? onAdd : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: canAdd
                  ? colorScheme.outline
                  : colorScheme.outline.withOpacity(0.5),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: canAdd
                    ? colorScheme.primary
                    : colorScheme.outline.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                canAdd ? AppLocalizations.of(context).roundSetupAddPlayer : AppLocalizations.of(context).roundSetupMaxPlayersShort,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: canAdd
                      ? colorScheme.primary
                      : colorScheme.outline.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
