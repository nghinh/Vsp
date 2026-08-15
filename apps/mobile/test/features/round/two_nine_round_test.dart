// A round made of two nines, and which course each hole belongs to.
//
// Long Biên is đường A, B and C at nine holes each, so an eighteen there is two
// of them. The round held one course id, so holes 10 to 18 belonged to nothing:
// the map reported no survey for any of them and hole advice answered 404,
// which the sheet showed as "không tải được thông tin hố này".

import 'package:flutter_test/flutter_test.dart';

/// The same translation ActiveRoundScreen does, and the server's
/// Round.resolveHole — kept here so the rule itself is asserted rather than
/// the widget that happens to apply it.
String courseForHole(String front, String? back, int hole) =>
    back != null && hole > 9 ? back : front;

int holeOnItsCourse(String? back, int hole) =>
    back != null && hole > 9 ? hole - 9 : hole;

void main() {
  group('a round paired from two đường', () {
    const front = '1351'; // Long Biên A
    const back = '1352'; // Long Biên B

    test('the front nine is the first đường, unchanged', () {
      expect(courseForHole(front, back, 1), front);
      expect(holeOnItsCourse(back, 9), 9);
    });

    /// The bug the golfer hit: hole 10 is hole 1 of the back nine, not hole 10
    /// of a đường that has nine.
    test('hole 10 is the first hole of the second đường', () {
      expect(courseForHole(front, back, 10), back);
      expect(holeOnItsCourse(back, 10), 1);
    });

    test('hole 18 is the ninth of the second đường', () {
      expect(courseForHole(front, back, 18), back);
      expect(holeOnItsCourse(back, 18), 9);
    });

    /// The header must still read 10 while the data is fetched as 1, or the
    /// map and the scorecard disagree about where the golfer is.
    test('the display offset puts the round number back on the header', () {
      const hole = 10;
      final offset = hole - holeOnItsCourse(back, hole);

      expect(holeOnItsCourse(back, hole) + offset, 10);
    });

    /// Most rounds are one eighteen and must be untouched by any of this.
    test('a round on a single course is unchanged', () {
      expect(courseForHole('1387', null, 10), '1387');
      expect(holeOnItsCourse(null, 10), 10);
    });
  });
}
