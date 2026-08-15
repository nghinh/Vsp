// The games engine, which decides who pays.
//
// Every case here is a real clubhouse argument. The stroke lands on the wrong
// hole, the tied skin does not carry, the settlement double-counts a debt —
// each one is a number somebody pays that they should not have, which is worse
// than a crash because it looks like an answer.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/games/domain/games_engine.dart';

const an = GamePlayer(id: 'an', name: 'An', handicap: 0);
const binh = GamePlayer(id: 'binh', name: 'Bình', handicap: 4);
const cuong = GamePlayer(id: 'cuong', name: 'Cường', handicap: 9);

final nineHoles = [for (var h = 1; h <= 9; h++) h];
final eighteen = [for (var h = 1; h <= 18; h++) h];

/// A card whose stroke index ranks hole h as the h-th hardest — legible in
/// assertions, unlike a real card's ordering.
final si18 = {for (var h = 1; h <= 18; h++) h: h};
final si9 = {for (var h = 1; h <= 9; h++) h: h};

Map<int, int> flat(int strokes, List<int> holes) =>
    {for (final h in holes) h: strokes};

GamesEngine engine({
  required List<GamePlayer> players,
  required Map<String, Map<int, int>> gross,
  List<int>? holes,
  Map<int, int>? si,
  GameType type = GameType.matchPlay,
  int stake = 1,
  bool useNet = true,
}) =>
    GamesEngine(
      players: players,
      holeNumbers: holes ?? eighteen,
      strokeIndexes: si ?? si18,
      gross: gross,
      config: GameConfig(type: type, stake: stake, useNet: useNet),
    );

void main() {
  group('chấp gậy — the strokes land on the right holes', () {
    /// Bình (4) plays An (0): four strokes, on SI 1..4 and nowhere else.
    test('the difference goes to the hardest holes', () {
      final e = engine(players: const [an, binh], gross: const {});

      expect(e.strokesOn(binh, 1), 1);
      expect(e.strokesOn(binh, 4), 1);
      expect(e.strokesOn(binh, 5), 0);
      expect(e.strokesOn(an, 1), 0);
    });

    /// Off the lowest: Cường (9) vs Bình (4) is five strokes, not nine.
    test('everyone plays off the lowest handicap in the flight', () {
      final e = engine(players: const [binh, cuong], gross: const {});

      expect(e.strokesOn(cuong, 5), 1);
      expect(e.strokesOn(cuong, 6), 0);
      expect(e.strokesOn(binh, 1), 0);
    });

    /// Handicap 20 over 18 holes: one everywhere, a second on SI 1-2.
    test('past eighteen the allocation laps the card', () {
      const heavy = GamePlayer(id: 'h', name: 'H', handicap: 20);
      final e = engine(players: const [an, heavy], gross: const {});

      expect(e.strokesOn(heavy, 1), 2);
      expect(e.strokesOn(heavy, 2), 2);
      expect(e.strokesOn(heavy, 3), 1);
      expect(e.strokesOn(heavy, 18), 1);
    });

    /// Half the country's cards publish no index. Guessing would put strokes
    /// on the wrong holes, so the engine refuses and plays gross.
    test('no stroke index means gross, not an invented allocation', () {
      final e = engine(players: const [an, binh], gross: const {}, si: const {});

      expect(e.canPlayNet, isFalse);
      expect(e.strokesOn(binh, 1), 0);
    });
  });

  group('match play', () {
    test('a hole is won by the lower net, and strokes decide it', () {
      // Gross all-square every hole; Bình's four strokes win SI 1-4.
      final e = engine(players: const [an, binh], gross: {
        'an': flat(4, eighteen),
        'binh': flat(4, eighteen),
      });

      final m = e.compute().matches.single;
      expect(m.aUp, -4);
      expect(m.holesPlayed, 18);
    });

    test('standings are live: unscored holes simply do not count yet', () {
      final e = engine(
        players: const [an, binh],
        useNet: false,
        gross: {
          'an': flat(4, [1, 2, 3]),
          'binh': flat(5, [1, 2, 3]),
        },
      );

      final m = e.compute().matches.single;
      expect(m.holesPlayed, 3);
      expect(m.aUp, 3);
    });

    test('đánh theo hố lệch: settlement is stake × holes up, per pair', () {
      final e = engine(
        players: const [an, binh],
        stake: 10,
        gross: {
          'an': flat(4, eighteen),
          'binh': flat(4, eighteen), // −4 after strokes
        },
      );

      final t = e.compute().transfers.single;
      expect(t.from.id, 'an');
      expect(t.to.id, 'binh');
      expect(t.amount, 40);
    });
  });

  group('nassau', () {
    /// Front lost, back won bigger, total won: 2−1 to the comeback.
    test('is three separate bets, so a comeback pays', () {
      // Front: Bình takes it 5 holes to 4. Back: An sweeps all nine. The
      // eighteen then goes to An 13-5 — so An wins two bets of the three.
      final gross = {
        'an': {...flat(5, [1, 2, 3, 4, 5]), ...flat(4, [6, 7, 8, 9]),
               ...flat(4, [for (var h = 10; h <= 18; h++) h])},
        'binh': {...flat(4, [1, 2, 3, 4, 5]), ...flat(5, [6, 7, 8, 9]),
                 ...flat(5, [for (var h = 10; h <= 18; h++) h])},
      };
      final e = engine(
        players: const [an, binh],
        type: GameType.nassau,
        stake: 10,
        useNet: false,
        gross: gross,
      );

      final t = e.compute().transfers.single;
      // Bình takes the front (−10 to An); An takes back and total (+20).
      expect(t.from.id, 'binh');
      expect(t.to.id, 'an');
      expect(t.amount, 10);
    });

    test('a nine-hole round has no back nine to bet on', () {
      final e = engine(
        players: const [an, binh],
        holes: nineHoles,
        si: si9,
        type: GameType.nassau,
        stake: 10,
        useNet: false,
        gross: {
          'an': flat(4, nineHoles),
          'binh': flat(5, nineHoles),
        },
      );

      // One bet, not three: 10, not 30.
      expect(e.compute().transfers.single.amount, 10);
    });
  });

  group('skins', () {
    test('the lowest unique net takes the hole from everyone', () {
      final e = engine(
        players: const [an, binh, cuong],
        holes: nineHoles,
        si: si9,
        type: GameType.skins,
        stake: 5,
        useNet: false,
        gross: {
          'an': {...flat(4, nineHoles), 1: 3},
          'binh': flat(4, nineHoles),
          'cuong': flat(4, nineHoles),
        },
      );

      final r = e.compute();
      expect(r.skins.single.holeNumber, 1);
      expect(r.skins.single.winner.id, 'an');
      // An collects 5 from each of the other two.
      expect(r.transfers.map((t) => t.amount).reduce((a, b) => a + b), 10);
    });

    /// The rule that makes the 18th worth six beers.
    test('a tie carries the hole into the next', () {
      final e = engine(
        players: const [an, binh],
        holes: nineHoles,
        si: si9,
        type: GameType.skins,
        stake: 5,
        useNet: false,
        gross: {
          'an': {...flat(4, nineHoles), 3: 3},
          'binh': flat(4, nineHoles),
        },
      );

      final skin = e.compute().skins.single;
      expect(skin.holeNumber, 3);
      expect(skin.carriedHoles, 2); // holes 1 and 2 tied into it
      expect(e.compute().transfers.single.amount, 15); // 3 holes × 5
    });

    test('money still on the table is said, not lost', () {
      final e = engine(
        players: const [an, binh],
        holes: nineHoles,
        si: si9,
        type: GameType.skins,
        useNet: false,
        gross: {
          'an': flat(4, nineHoles),
          'binh': flat(4, nineHoles),
        },
      );

      expect(e.compute().carriedIntoNext, 9);
      expect(e.compute().transfers, isEmpty);
    });
  });

  group('settlement', () {
    /// The whole point of doing this in software: the ledger nets down to the
    /// fewest transfers, and every đồng is conserved.
    test('nets crossing debts and conserves the total', () {
      final e = engine(
        players: const [an, binh, cuong],
        holes: nineHoles,
        si: si9,
        type: GameType.skins,
        stake: 5,
        useNet: true,
        gross: {
          'an': flat(4, nineHoles),
          'binh': flat(4, nineHoles),
          'cuong': flat(5, nineHoles),
        },
      );

      final r = e.compute();
      final paid = <String, int>{};
      for (final t in r.transfers) {
        paid[t.from.id] = (paid[t.from.id] ?? 0) - t.amount;
        paid[t.to.id] = (paid[t.to.id] ?? 0) + t.amount;
      }
      expect(paid.values.fold(0, (a, b) => a + b), 0);
      // Nobody both pays and receives.
      for (final t in r.transfers) {
        expect(r.transfers.any((o) => o.to.id == t.from.id), isFalse);
      }
    });
  });
}
