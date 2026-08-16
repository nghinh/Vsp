// How a score is shown — VSP Mobile App
//
// The same round reads three ways, and golfers switch between them without
// thinking: 87 gross, 15 over, 72 net. The card only ever showed the first,
// so the two questions a golfer actually asks out loud — "how far over am
// I?" and "what am I net?" — had to be done in their head, on a cart, in
// the sun.
//
// Net is the one with teeth: it needs the golfer's playing handicap and the
// club's stroke index, and where either is missing the honest answer is to
// refuse rather than to show a number that looks like a net score and is
// not one. The same rule the games sheet already follows.

import 'package:flutter/foundation.dart';

enum ScoreDisplayMode { gross, net, toPar }

@immutable
class ScoreDisplay {
  const ScoreDisplay({
    required this.grossByHole,
    required this.parByHole,
    this.strokeIndexes = const {},
    this.handicap,
  });

  /// This player's strokes, by hole number.
  final Map<int, int> grossByHole;

  /// The hole's par, by hole number.
  final Map<int, int> parByHole;

  /// Stroke index by hole number, from the club's card. Empty where the club
  /// published none — half the country.
  final Map<int, int> strokeIndexes;

  /// The player's playing handicap. Null where nobody has one on file.
  final int? handicap;

  /// Whether a net score can honestly be computed.
  ///
  /// Both halves are required. A net score built on a guessed allocation
  /// puts the shots on the wrong holes, and the number still looks right.
  bool get canShowNet => handicap != null && strokeIndexes.isNotEmpty;

  /// Holes with a score entered, in order.
  List<int> get scoredHoles {
    final holes = grossByHole.keys.where((h) => grossByHole[h] != null).toList()
      ..sort();
    return holes;
  }

  /// Shots this player receives on a hole, from their own handicap and the
  /// hole's index — laps past 18 where the handicap is bigger than the card.
  int strokesOn(int holeNumber, {int holesInRound = 18}) {
    final playing = handicap;
    final si = strokeIndexes[holeNumber];
    if (playing == null || si == null) return 0;
    if (playing < 0) {
      // A plus handicap gives shots back, easiest holes first.
      final given = (-playing) ~/ holesInRound;
      final remainder = (-playing) % holesInRound;
      return -(given + (si > holesInRound - remainder ? 1 : 0));
    }
    return playing ~/ holesInRound + (si <= playing % holesInRound ? 1 : 0);
  }

  /// The running total in [mode] over the holes scored so far, or null when
  /// nothing is scored — or when net was asked for and cannot be given.
  int? total(ScoreDisplayMode mode, {int holesInRound = 18}) {
    final holes = scoredHoles;
    if (holes.isEmpty) return null;
    if (mode == ScoreDisplayMode.net && !canShowNet) return null;

    var sum = 0;
    for (final hole in holes) {
      final gross = grossByHole[hole]!;
      switch (mode) {
        case ScoreDisplayMode.gross:
          sum += gross;
        case ScoreDisplayMode.toPar:
          final par = parByHole[hole];
          if (par == null) continue;
          sum += gross - par;
        case ScoreDisplayMode.net:
          sum += gross - strokesOn(hole, holesInRound: holesInRound);
      }
    }
    return sum;
  }

  /// The total as it should read on screen: "+3" and "E" mean something in
  /// to-par and nothing in the other two.
  String label(ScoreDisplayMode mode, {int holesInRound = 18}) {
    final value = total(mode, holesInRound: holesInRound);
    if (value == null) return '—';
    if (mode != ScoreDisplayMode.toPar) return '$value';
    if (value == 0) return 'E';
    return value > 0 ? '+$value' : '$value';
  }
}
