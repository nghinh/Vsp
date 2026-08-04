// Progressive Disclosure Panel — VSP Mobile App
//
// Panel showing progressive score fields (putts, penalties, fairway, GIR, bunker, notes)
// for the selected player. Revealed via expansion from gross score entry.
//
// Animation: 150–200ms subtle slide + fade.
//
// Story 5.3 — Slice 4: Progressive Disclosure

import 'package:flutter/material.dart';

import '../../../domain/models/score.dart';
import 'bunker_toggle.dart';
import 'fairway_gir_toggle.dart';
import 'progressive_score_field.dart';

/// Panel displaying progressive score fields for a single player.
/// Shows putts, penalties, fairway/GIR toggles, bunker toggle, and notes.
class ProgressiveDisclosurePanel extends StatelessWidget {
  /// The score for this player on the current hole.
  final Score? score;

  /// Player display name.
  final String playerName;

  /// Minimum touch target size.
  static const double kMinTouchTarget = 44.0;

  // Putts callbacks
  final VoidCallback onIncrementPutts;
  final VoidCallback onDecrementPutts;
  final VoidCallback? onClearPutts;

  // Penalties callbacks
  final VoidCallback onIncrementPenalties;
  final VoidCallback onDecrementPenalties;
  final VoidCallback? onClearPenalties;

  // Fairway/GIR callbacks
  final VoidCallback onFairwayYes;
  final VoidCallback onFairwayNo;
  final VoidCallback onFairwayClear;
  final VoidCallback onGirYes;
  final VoidCallback onGirNo;
  final VoidCallback onGirClear;

  // Bunker callbacks
  final VoidCallback onBunkerYes;
  final VoidCallback onBunkerNo;
  final VoidCallback onBunkerClear;

  // Notes callbacks
  final VoidCallback onNotesTap;

  /// Whether this panel is visible (score exists).
  final bool isVisible;

  const ProgressiveDisclosurePanel({
    super.key,
    required this.score,
    required this.playerName,
    required this.onIncrementPutts,
    required this.onDecrementPutts,
    this.onClearPutts,
    required this.onIncrementPenalties,
    required this.onDecrementPenalties,
    this.onClearPenalties,
    required this.onFairwayYes,
    required this.onFairwayNo,
    required this.onFairwayClear,
    required this.onGirYes,
    required this.onGirNo,
    required this.onGirClear,
    required this.onBunkerYes,
    required this.onBunkerNo,
    required this.onBunkerClear,
    required this.onNotesTap,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProgressiveReveal(
      isExpanded: isVisible && score != null,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stats — $playerName',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Putts and Penalties steppers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ProgressiveScoreField(
                    label: 'Putts',
                    value: score?.putts,
                    onIncrement: onIncrementPutts,
                    onDecrement: onDecrementPutts,
                    onClear: onClearPutts,
                    semanticLabel: 'Putts for $playerName',
                  ),
                  ProgressiveScoreField(
                    label: 'Penalties',
                    value: score?.penalties,
                    onIncrement: onIncrementPenalties,
                    onDecrement: onDecrementPenalties,
                    onClear: onClearPenalties,
                    semanticLabel: 'Penalties for $playerName',
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Fairway/GIR toggles
            FairwayGirToggles(
              fairwayState: _toStatToggleState(score?.fairwayHit),
              girState: _toStatToggleState(score?.gir),
              onFairwayYes: onFairwayYes,
              onFairwayNo: onFairwayNo,
              onFairwayClear: onFairwayClear,
              onGirYes: onGirYes,
              onGirNo: onGirNo,
              onGirClear: onGirClear,
            ),

            const Divider(height: 1),

            // Bunker toggle + Notes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  BunkerToggle(
                    state: _toStatToggleState(score?.bunker),
                    onToggleYes: onBunkerYes,
                    onToggleNo: onBunkerNo,
                    onClear: onBunkerClear,
                    semanticLabel: 'Bunker shot for $playerName',
                  ),
                  const Spacer(),
                  // Notes button
                  Semantics(
                    label:
                        'Notes for $playerName${score?.notes != null && score!.notes!.isNotEmpty ? ': ${score!.notes}' : ''}',
                    button: true,
                    child: InkWell(
                      onTap: onNotesTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              score?.notes?.isNotEmpty == true
                                  ? '${score!.notes}'
                                  : 'Notes',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: score?.notes?.isNotEmpty == true
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  StatToggleState _toStatToggleState(bool? value) {
    if (value == null) return StatToggleState.unset;
    return value ? StatToggleState.yes : StatToggleState.no;
  }
}
