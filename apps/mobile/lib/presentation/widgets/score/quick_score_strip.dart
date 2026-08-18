// The score, in one tap.
//
// Recording a score was the most frequent thing anybody does in this app — 18
// holes times however many golfers are in the flight — and it had no one-tap
// path. Two routes existed and both were long:
//
//   +/-      one tap per stroke from nothing, so a 4 cost four taps
//   the number  opened a sheet with a text field, the system keyboard, a 1-9
//               pad and a Confirm button: four interactions and a keyboard,
//               for a single digit
//
// A golf score is not an arbitrary number. It is almost always par, one
// either side, or two over — the hole tells you what to offer. So the row
// offers those directly, labelled with the actual number a golfer would
// write, and the answer is one tap. Anything outside the range still has the
// keypad behind "…", where it belongs: rare, and worth the extra taps.
//
// Sized for the hand this is used by. 56pt tall against a 44pt minimum,
// because the minimum is for an index finger indoors and this is a thumb in a
// glove; and the selected state carries a tick as well as a fill, because
// colour is the first thing bright sun takes away.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

/// One-tap scoring for the scores a hole actually produces.
class QuickScoreStrip extends StatelessWidget {
  const QuickScoreStrip({
    super.key,
    required this.par,
    required this.score,
    required this.onScore,
    required this.onOther,
  });

  /// The hole's par. The whole strip is relative to it.
  final int par;

  /// What is recorded now, so the golfer can see their own entry and change
  /// it without first clearing it.
  final int? score;

  /// Records a score outright — not an increment.
  final ValueChanged<int> onScore;

  /// Opens the full keypad, for the hole that went wrong.
  final VoidCallback onOther;

  /// Birdie through triple bogey.
  ///
  /// Eagles are not here on purpose. They are rarer than the strip is wide,
  /// and buying one with a narrower target for the four scores that happen
  /// every round is a bad trade — the keypad still takes a 2 on a par 5.
  static const _offsets = [-1, 0, 1, 2, 3];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    String caption(int offset) => switch (offset) {
      -1 => l10n.scoreBirdie,
      0 => l10n.scorePar,
      1 => l10n.scoreBogey,
      _ => '+$offset',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          for (final offset in _offsets) ...[
            Expanded(
              child: _ScoreButton(
                // The number a golfer writes on the card. The caption under it
                // is the name; the number is the thing being chosen, so it is
                // the thing that is large.
                label: '${par + offset}',
                caption: caption(offset),
                selected: score == par + offset,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onScore(par + offset);
                },
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: _ScoreButton(
              label: '…',
              caption: l10n.scoreOther,
              // Marked as chosen when the entry is outside the strip, so a 9
              // does not look like no score at all.
              selected: score != null &&
                  !_offsets.map((o) => par + o).contains(score),
              onPressed: onOther,
              muted: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreButton extends StatelessWidget {
  const _ScoreButton({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onPressed,
    this.muted = false,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onPressed;

  /// The "…" key, which is a way out rather than an answer, and should not
  /// compete with the five that are.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onPrimary
        : muted
            ? scheme.onSurfaceVariant
            : scheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: '$caption $label',
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            // A floor, not a ceiling. 56 is what a thumb in a glove needs;
            // writing it as a fixed height meant a golfer who turns their text
            // up got the number and its caption clipped out of a box that
            // refused to grow. The key gets taller, which is what somebody
            // asking for bigger text asked for.
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: foreground.withOpacity(selected ? 0.9 : 0.7),
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
