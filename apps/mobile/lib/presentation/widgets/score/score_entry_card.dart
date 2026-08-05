// Score Entry Card — VSP Mobile App
//
// Card containing all player score rows for a single hole.
// Handles expanding individual player rows on tap.
//
// Story 5.3 — Slice 3: Score Entry UI (updated Slice 4: Progressive Disclosure)

import 'package:flutter/material.dart';

import '../../../domain/models/score.dart';
import 'player_score_row.dart';
import 'progressive_disclosure_panel.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Card widget containing score rows for all players on one hole.
class ScoreEntryCard extends StatefulWidget {
  /// Player IDs and names.
  final List<String> playerIds;
  final Map<String, String> playerNames;

  /// Map of playerId → current gross score (null if not entered).
  final Map<String, int?> grossScores;

  /// Map of playerId → whether score has been entered.
  final Map<String, bool> enteredFlags;

  /// Map of playerId → Score (for progressive fields).
  final Map<String, Score?> playerScores;

  /// Callback when increment score is pressed for a player.
  final void Function(String playerId) onIncrement;

  /// Callback when decrement score is pressed for a player.
  final void Function(String playerId) onDecrement;

  /// Callback when score number is tapped for direct entry.
  final void Function(String playerId) onScoreTap;

  // Progressive field callbacks
  final void Function(String playerId) onIncrementPutts;
  final void Function(String playerId) onDecrementPutts;
  final void Function(String playerId) onIncrementPenalties;
  final void Function(String playerId) onDecrementPenalties;
  final void Function(String playerId, bool) onFairwayHit;
  final void Function(String playerId, bool) onGir;
  final void Function(String playerId, bool) onBunker;
  final void Function(String playerId) onNotesTap;

  const ScoreEntryCard({
    super.key,
    required this.playerIds,
    required this.playerNames,
    required this.grossScores,
    required this.enteredFlags,
    required this.playerScores,
    required this.onIncrement,
    required this.onDecrement,
    required this.onScoreTap,
    required this.onIncrementPutts,
    required this.onDecrementPutts,
    required this.onIncrementPenalties,
    required this.onDecrementPenalties,
    required this.onFairwayHit,
    required this.onGir,
    required this.onBunker,
    required this.onNotesTap,
  });

  @override
  State<ScoreEntryCard> createState() => _ScoreEntryCardState();
}

class _ScoreEntryCardState extends State<ScoreEntryCard> {
  String? _expandedPlayerId;

  void _toggleExpand(String playerId) {
    setState(() {
      _expandedPlayerId = _expandedPlayerId == playerId ? null : playerId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final expandedPlayerId = _expandedPlayerId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Player rows card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Section header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context).scorecardScores,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.enteredFlags.values.where((e) => e).length}/${widget.playerIds.length} entered',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Player rows
              ...widget.playerIds.map((playerId) {
                final status = widget.enteredFlags[playerId] == true
                    ? PlayerScoreStatus.entered
                    : PlayerScoreStatus.notEntered;

                return InkWell(
                  onTap: () => _toggleExpand(playerId),
                  child: PlayerScoreRow(
                    playerName: widget.playerNames[playerId] ?? playerId,
                    grossScore: widget.grossScores[playerId],
                    status: status,
                    isExpanded: expandedPlayerId == playerId,
                    onIncrement: () => widget.onIncrement(playerId),
                    onDecrement: () => widget.onDecrement(playerId),
                    onScoreTap: () => widget.onScoreTap(playerId),
                  ),
                );
              }),
            ],
          ),
        ),

        // Progressive disclosure panel for expanded player
        if (expandedPlayerId != null)
          ProgressiveDisclosurePanel(
            score: widget.playerScores[expandedPlayerId],
            playerName:
                widget.playerNames[expandedPlayerId] ?? expandedPlayerId,
            isVisible: true,
            onIncrementPutts: () => widget.onIncrementPutts(expandedPlayerId),
            onDecrementPutts: () => widget.onDecrementPutts(expandedPlayerId),
            onIncrementPenalties: () =>
                widget.onIncrementPenalties(expandedPlayerId),
            onDecrementPenalties: () =>
                widget.onDecrementPenalties(expandedPlayerId),
            onFairwayYes: () => widget.onFairwayHit(expandedPlayerId, true),
            onFairwayNo: () => widget.onFairwayHit(expandedPlayerId, false),
            onFairwayClear: () => widget.onFairwayHit(expandedPlayerId, false),
            onGirYes: () => widget.onGir(expandedPlayerId, true),
            onGirNo: () => widget.onGir(expandedPlayerId, false),
            onGirClear: () => widget.onGir(expandedPlayerId, false),
            onBunkerYes: () => widget.onBunker(expandedPlayerId, true),
            onBunkerNo: () => widget.onBunker(expandedPlayerId, false),
            onBunkerClear: () => widget.onBunker(expandedPlayerId, false),
            onNotesTap: () => widget.onNotesTap(expandedPlayerId),
          ),
      ],
    );
  }
}
