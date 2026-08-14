// What a club is called.
//
// ClubType is DRIVER, WOOD, HYBRID, IRON, WEDGE, PUTTER and stops there, so a
// bag of fourteen read "Iron" eight times and "Fairway Wood" three — a list a
// golfer cannot use, because they think in the number on the sole.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/bag/data/bag_dto.dart';
import 'package:vsp_mobile/features/bag/domain/club_naming.dart';

void main() {
  group('naming a club', () {
    test('gives an iron its number', () {
      expect(ClubNaming.name(ClubType.iron, 34), 'Sắt 7');
      expect(ClubNaming.name(ClubType.iron, 27), 'Sắt 5');
      expect(ClubNaming.name(ClubType.iron, 42), 'Sắt 9');
    });

    test('gives a wood and a hybrid theirs', () {
      expect(ClubNaming.name(ClubType.wood, 15), 'Gỗ 3');
      expect(ClubNaming.name(ClubType.wood, 18), 'Gỗ 5');
      expect(ClubNaming.name(ClubType.hybrid, 21), 'Hybrid 4');
    });

    test('names the wedges the way golfers say them', () {
      expect(ClubNaming.name(ClubType.wedge, 46), 'Pitching wedge');
      expect(ClubNaming.name(ClubType.wedge, 54), 'Sand wedge');
      expect(ClubNaming.name(ClubType.wedge, 58), 'Lob wedge');
    });

    // Neighbouring irons sit three or four degrees apart, so a club within two
    // of a standard loft is that club — one maker's 7-iron is another's 6.
    test('tolerates the loft being a little off', () {
      expect(ClubNaming.name(ClubType.iron, 35.5), 'Sắt 7');
      expect(ClubNaming.name(ClubType.iron, 32.5), 'Sắt 7');
    });

    // A driving iron at 16° is a real club that the standard set does not
    // describe. Forcing it into the nearest name would rename the golfer's own
    // club to something it is not.
    test('keeps the plain type for a club the set does not describe', () {
      expect(ClubNaming.name(ClubType.iron, 14), 'Sắt');
      expect(ClubNaming.name(ClubType.wood, 9), 'Gỗ');
    });

    test('keeps the plain type when no loft is on file', () {
      expect(ClubNaming.name(ClubType.iron, null), 'Sắt');
      expect(ClubNaming.name(ClubType.driver, null), 'Driver');
    });

    // A bag holds one of each of these, so there is no number to give.
    test('needs no number for a driver or a putter', () {
      expect(ClubNaming.name(ClubType.driver, 10.5), 'Driver');
      expect(ClubNaming.name(ClubType.putter, 3), 'Gậy putt');
    });

    test('names a club straight off its own row', () {
      const club = ClubDTO(id: 1, golfBagId: 1, clubType: ClubType.iron, loft: 34);

      expect(club.displayName, 'Sắt 7');
    });
  });
}
