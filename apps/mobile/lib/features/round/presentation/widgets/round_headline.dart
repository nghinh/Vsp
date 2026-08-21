// The top of the round summary: what you shot, and the nine totals.
//
// Split out of round_summary_screen.dart, which was six hundred lines with
// the screen's most-read widgets buried as private classes — untestable
// without standing up a bloc, a database and a preferences store to see
// whether a number is printed in the right place.

import 'package:flutter/material.dart';

import '../../domain/round_summary.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// What you shot, before anything else on the screen.
///
/// One golfer gets the number at headline size, because there is exactly one
/// answer and it is the reason this screen exists. A flight gets one line
/// each, best first — which is the thing a group actually reads, and which a
/// single headline for whoever happened to be first in the list would have
/// answered wrongly.
class RoundHeadline extends StatelessWidget {
  const RoundHeadline({
    required this.players,
    required this.courseName,
    required this.date,
  });

  final List<PlayerScoreSummary> players;
  final String courseName;
  final String date;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _CourseCaption(courseName: courseName, date: date),
      );
    }

    final ranked = [...players]
      ..sort((a, b) => a.totalStrokes.compareTo(b.totalStrokes));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ranked.length == 1)
            _SoloHeadline(player: ranked.first)
          else
            for (final player in ranked) _FlightLine(player: player),
          const SizedBox(height: 8),
          _CourseCaption(courseName: courseName, date: date),
        ],
      ),
    );
  }
}

class _SoloHeadline extends StatelessWidget {
  const _SoloHeadline({required this.player});

  final PlayerScoreSummary player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wrap, so at a large text size "+18" drops under the score instead of
    // pushing it off the right edge. The score is the reason the screen
    // exists; it does not shrink and it does not move.
    final toPar = relativeScoreLabelOrNull(
      player.relativeScore,
      player.totalPar,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        Text(
          '${player.totalStrokes}',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        if (toPar != null)
          Text(
            toPar,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: relativeScoreColour(context, player.relativeScore),
            ),
          ),
      ],
    );
  }
}

class _FlightLine extends StatelessWidget {
  const _FlightLine({required this.player});

  final PlayerScoreSummary player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              player.playerName,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Text(
            '${player.totalStrokes}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              // Empty rather than absent: four players' scores line up in a
              // column, and a missing cell would shuffle the row that has one.
              relativeScoreLabelOrNull(
                    player.relativeScore,
                    player.totalPar,
                  ) ??
                  '',
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: relativeScoreColour(context, player.relativeScore),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCaption extends StatelessWidget {
  const _CourseCaption({required this.courseName, required this.date});

  final String courseName;
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '$courseName · $date',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// OUT, IN and the total — how a scorecard is read everywhere else.
class NineTotals extends StatelessWidget {
  const NineTotals({required this.player});

  final PlayerScoreSummary player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    Widget cell(String label, int value, {bool emphasised = false}) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          cell(l10n.summaryOut, player.frontNineStrokes),
          cell(l10n.summaryIn, player.backNineStrokes),
          cell(l10n.summaryTotal, player.totalStrokes, emphasised: true),
        ],
      ),
    );
  }
}

/// "+3", "-1", "E" — the form a golfer says out loud.
String relativeScoreLabel(int relative) {
  if (relative == 0) return 'E';
  return relative > 0 ? '+$relative' : '$relative';
}

/// The same label, but silent when there is no par to be relative to.
///
/// Par reaches the summary only for holes the package carries geometry for,
/// and most holes in this country have none — so `relativeScore` came back 0
/// not because the golfer went round in level par but because nothing was
/// known. The headline printed that 0 as "E".
///
/// It was on a sales screenshot: "78 E" above a server-written recap saying
/// "+6 so với par 72", the two disagreeing about the same round in the same
/// picture. Same rule as the paired-round card — a screen must not judge a
/// score against a par nobody knows.
String? relativeScoreLabelOrNull(int relative, int totalPar) =>
    totalPar > 0 ? relativeScoreLabel(relative) : null;

/// Under par, over par, level — from the palette rather than from Material.
///
/// These were `Theme.of(context).colorScheme.tertiary`, `Theme.of(context).colorScheme.error` and `Colors.grey`: three constants
/// that belong to no palette in this project and answer to no contrast test.
/// Material's red measures 4.45:1 on this app's card surface, under the 4.5
/// floor, and it is the colour most scores are printed in.
Color relativeScoreColour(BuildContext context, int relative) {
  final scheme = Theme.of(context).colorScheme;
  if (relative < 0) return scheme.tertiary;
  if (relative > 0) return scheme.error;
  return scheme.onSurfaceVariant;
}

