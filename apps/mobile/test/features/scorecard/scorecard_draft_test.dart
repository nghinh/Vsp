// What a typed-in scorecard has to satisfy before it is worth a reviewer's
// time — and before it is allowed anywhere near a net score.
//
// Every rule here exists because of what goes wrong when eighteen lines are
// copied off a photograph by hand. A duplicated stroke index is the worst of
// them: it misallocates strokes on both holes, for everyone who plays that
// card afterwards, and nothing about the round looks wrong while it happens.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/scorecard/domain/scorecard_draft.dart';

void main() {
  ScorecardDraft complete({int holes = 18}) => ScorecardDraft(
    holeCount: holes,
    pars: {for (var h = 1; h <= holes; h++) h: h % 3 == 0 ? 3 : 4},
    strokeIndexes: {for (var h = 1; h <= holes; h++) h: h},
  );

  String? check(
    ScorecardDraft draft, {
    String name = 'A + B',
    List<int> segments = const [21, 22],
  }) => draft.validate(
    name: name,
    segmentCourseIds: segments,
    missingPar: (hole) => 'missing-par-$hole',
    missingIndex: (hole) => 'missing-index-$hole',
    duplicateIndex: (index) => 'duplicate-$index',
    nameRequired: 'name-required',
    segmentsRequired: 'segments-required',
  );

  test('a complete card passes', () {
    expect(check(complete()), isNull);
  });

  test('a nine-hole card is a card too', () {
    // Đường A on its own, printed as nine lines.
    expect(check(complete(holes: 9), segments: const [21]), isNull);
  });

  test('a hole with no par is named', () {
    final draft = complete();
    draft.pars.remove(7);

    expect(check(draft), 'missing-par-7');
  });

  test('a hole with no stroke index is named', () {
    final draft = complete();
    draft.strokeIndexes[12] = null;

    expect(check(draft), 'missing-index-12');
  });

  test('two holes sharing an index are refused', () {
    final draft = complete();
    draft.strokeIndexes[15] = 3;

    expect(check(draft), 'duplicate-3');
  });

  test('gaps are reported before duplicates', () {
    // A duplicate is often the consequence of a line the golfer has not
    // reached yet, so telling them about the gap first is the shorter path
    // to a card that is right.
    final draft = complete();
    draft.pars.remove(4);
    draft.strokeIndexes[15] = 3;

    expect(check(draft), 'missing-par-4');
  });

  test('a nameless card is refused', () {
    expect(check(complete(), name: '   '), 'name-required');
  });

  test('a card must name one or two đường', () {
    expect(check(complete(), segments: const []), 'segments-required');
    expect(
      check(complete(), segments: const [21, 22, 23]),
      'segments-required',
    );
  });

  test('the lines it sends carry the numbers that were typed', () {
    final draft = complete(holes: 9);

    final lines = draft.toLines();

    expect(lines, hasLength(9));
    expect(lines.first.hole, 1);
    expect(lines.first.par, 4);
    expect(lines[2].par, 3);
    expect(lines[2].strokeIndex, 3);
    expect(draft.parTotal, 4 + 4 + 3 + 4 + 4 + 3 + 4 + 4 + 3);
  });
}
