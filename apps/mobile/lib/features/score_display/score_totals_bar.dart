// The running total, in the mode the golfer asked for — VSP Mobile App
//
// Three questions golfers ask out loud during a round: how many have I hit,
// how far over am I, what am I net. The card answered only the first, and
// only by making them add it up.
//
// Net is offered only where it can be honest — a playing handicap and the
// club's stroke index — and says why when it cannot, rather than greying
// out with no explanation.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/games/data/stroke_index_api.dart';
import 'package:vsp_mobile/features/score_display/score_display.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class ScoreTotalsBar extends StatefulWidget {
  const ScoreTotalsBar({
    super.key,
    required this.playerIds,
    required this.playerNames,
    required this.grossByPlayer,
    required this.parByHole,
    this.playerHandicaps = const {},
    this.courseId,
    this.backNineCourseId,
    this.api,
    this.strokeIndexes,
  });

  final List<String> playerIds;
  final Map<String, String> playerNames;

  /// Strokes by hole number, per player.
  final Map<String, Map<int, int>> grossByPlayer;

  final Map<int, int> parByHole;
  final Map<String, int> playerHandicaps;

  final int? courseId;
  final int? backNineCourseId;

  final StrokeIndexApi? api;

  /// Injectable for tests; fetched when null.
  final Map<int, int>? strokeIndexes;

  @override
  State<ScoreTotalsBar> createState() => _ScoreTotalsBarState();
}

class _ScoreTotalsBarState extends State<ScoreTotalsBar> {
  ScoreDisplayMode _mode = ScoreDisplayMode.gross;
  Map<int, int> _strokeIndexes = const {};

  @override
  void initState() {
    super.initState();
    _loadStrokeIndexes();
  }

  Future<void> _loadStrokeIndexes() async {
    if (widget.strokeIndexes != null) {
      setState(() => _strokeIndexes = widget.strokeIndexes!);
      return;
    }
    final courseId = widget.courseId;
    if (courseId == null) return;
    try {
      final si = await (widget.api ?? StrokeIndexApi()).forRound(
        courseId: courseId,
        backNineCourseId: widget.backNineCourseId,
      );
      if (!mounted) return;
      setState(() => _strokeIndexes = si);
    } catch (_) {
      // Offline, or the club published no index. Net simply stays refused.
    }
  }

  ScoreDisplay _displayFor(String playerId) => ScoreDisplay(
        grossByHole: widget.grossByPlayer[playerId] ?? const {},
        parByHole: widget.parByHole,
        strokeIndexes: _strokeIndexes,
        handicap: widget.playerHandicaps[playerId],
      );

  bool get _netPossible =>
      widget.playerIds.any((id) => _displayFor(id).canShowNet);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Before anything is scored there is no total to show, and a row of
    // dashes is noise on the hole a golfer is trying to enter.
    final anyScores = widget.playerIds
        .any((id) => _displayFor(id).scoredHoles.isNotEmpty);
    if (!anyScores) return const SizedBox.shrink();

    final mode = _mode == ScoreDisplayMode.net && !_netPossible
        ? ScoreDisplayMode.gross
        : _mode;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: VspSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<ScoreDisplayMode>(
            key: const Key('score_display_mode'),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                value: ScoreDisplayMode.gross,
                label: Text(l10n.scoreDisplayGross),
              ),
              ButtonSegment(
                value: ScoreDisplayMode.net,
                label: Text(l10n.scoreDisplayNet),
                enabled: _netPossible,
              ),
              ButtonSegment(
                value: ScoreDisplayMode.toPar,
                label: Text(l10n.scoreDisplayToPar),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: VspSpacing.xs),
          Wrap(
            spacing: VspSpacing.md,
            runSpacing: VspSpacing.xs,
            children: [
              for (final id in widget.playerIds)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.playerNames[id] ?? id}: ',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      _displayFor(id).label(mode),
                      style: const TextStyle(
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (!_netPossible)
            Text(
              l10n.scoreDisplayNetUnavailable,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
