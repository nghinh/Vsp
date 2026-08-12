// The card a golfer is typing in, and what makes it submittable.
//
// Kept apart from the screen so the rules can be tested without pumping a
// widget: they are the same rules the server enforces, and every one of them
// exists because of what goes wrong when a card is read off a photograph by
// hand.

import '../data/scorecard_api.dart';

class ScorecardDraft {
  ScorecardDraft({
    required this.holeCount,
    Map<int, int>? pars,
    Map<int, int?>? strokeIndexes,
  }) : pars = pars ?? {},
       strokeIndexes = strokeIndexes ?? {};

  final int holeCount;

  /// Par per hole number. Absent means the golfer has not typed it yet.
  final Map<int, int> pars;

  /// Stroke index per hole number.
  final Map<int, int?> strokeIndexes;

  List<int> get holeNumbers =>
      List<int>.generate(holeCount, (index) => index + 1);

  int get parTotal => pars.values.fold(0, (sum, par) => sum + par);

  List<ScorecardLine> toLines() => holeNumbers
      .map(
        (hole) => ScorecardLine(
          hole: hole,
          par: pars[hole] ?? 4,
          strokeIndex: strokeIndexes[hole],
        ),
      )
      .toList();

  /// The first thing wrong with this card, or null when it is ready to send.
  ///
  /// Order matters: a golfer is told about a hole they have not filled in
  /// before being told about a duplicate, because the duplicate may be a
  /// consequence of the gap.
  String? validate({
    required String name,
    required List<int> segmentCourseIds,
    required String Function(int hole) missingPar,
    required String Function(int hole) missingIndex,
    required String Function(int index) duplicateIndex,
    required String nameRequired,
    required String segmentsRequired,
  }) {
    if (name.trim().isEmpty) {
      return nameRequired;
    }
    if (segmentCourseIds.isEmpty || segmentCourseIds.length > 2) {
      return segmentsRequired;
    }

    for (final hole in holeNumbers) {
      if (pars[hole] == null) {
        return missingPar(hole);
      }
    }
    for (final hole in holeNumbers) {
      if (strokeIndexes[hole] == null) {
        return missingIndex(hole);
      }
    }

    final seen = <int, int>{};
    for (final hole in holeNumbers) {
      final index = strokeIndexes[hole];
      if (index == null) {
        continue;
      }
      if (seen.containsKey(index)) {
        // Two holes cannot share an index: the card hands each number out
        // once, and a duplicate misallocates strokes on both of them for
        // everyone who plays there afterwards.
        return duplicateIndex(index);
      }
      seen[index] = hole;
    }

    return null;
  }
}
