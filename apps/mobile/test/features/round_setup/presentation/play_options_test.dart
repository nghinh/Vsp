// Every way a club can actually be played, worked out in advance.
//
// The form used to ask two questions — pick a đường, then pick the one you
// are pairing it with — which made the golfer assemble a round the club
// already sells as a single thing, and let them assemble combinations nobody
// plays. Long Biên offers A→B, A→C, B→C and their reverses, plus each nine
// on its own; that is a list, not a puzzle.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const duongA = LayoutOption(id: 21, name: 'Đường A', holeCount: 9);
  const duongB = LayoutOption(id: 22, name: 'Đường B', holeCount: 9);
  const duongC = LayoutOption(id: 23, name: 'Đường C', holeCount: 9);
  const championship =
      LayoutOption(id: 1, name: 'Championship', holeCount: 18);

  RoundSetupReady club(List<LayoutOption> layouts, {int? first, int? second}) =>
      RoundSetupReady(
        courseId: 21,
        courseName: 'Long Biên',
        layouts: layouts,
        selectedLayoutId: first,
        selectedSecondLayoutId: second,
      );

  group('playOptions', () {
    test('three nines make six pairings and three nines on their own', () {
      final options = club([duongA, duongB, duongC]).playOptions;

      expect(options.where((o) => o.isPairing), hasLength(6));
      expect(options.where((o) => !o.isPairing), hasLength(3));
      expect(
        options.where((o) => o.isPairing).map((o) => o.name),
        contains('Đường A → Đường C'),
      );
    });

    test('a pairing is eighteen holes, a nine is nine', () {
      final options = club([duongA, duongB]).playOptions;

      expect(options.first.holeCount, 18);
      expect(options.last.holeCount, 9);
    });

    test('both directions, because they number the holes differently', () {
      // Round hole 12 on A→C is C's third; on C→A it is A's third.
      final names =
          club([duongA, duongC]).playOptions.map((o) => o.name).toList();

      expect(names, contains('Đường A → Đường C'));
      expect(names, contains('Đường C → Đường A'));
    });

    test('an eighteen stands alone, and comes first', () {
      final options = club([championship, duongA, duongB]).playOptions;

      expect(options.first.name, 'Championship');
      expect(options.first.isPairing, isFalse);
      expect(options.first.holeCount, 18);
    });

    test('a club with one layout offers no choice to make', () {
      expect(club([championship]).playOptions, hasLength(1));
    });
  });

  group('selectedPlayOption', () {
    test('finds the pairing the form is on', () {
      final state = club([duongA, duongB, duongC], first: 21, second: 23);

      expect(state.selectedPlayOption?.name, 'Đường A → Đường C');
    });

    test('finds a single nine, which is not the same as a pairing', () {
      final state = club([duongA, duongB], first: 21);

      expect(state.selectedPlayOption?.isPairing, isFalse);
      expect(state.selectedPlayOption?.holeCount, 9);
    });

    test('is null before the golfer has chosen', () {
      expect(club([duongA, duongB]).selectedPlayOption, isNull);
    });
  });
}
