// What to call a club — VSP Mobile App
//
// ClubType is DRIVER, WOOD, HYBRID, IRON, WEDGE, PUTTER and stops there, so a
// bag of fourteen showed "Iron" eight times and "Fairway Wood" three. A golfer
// does not think in club types; they think in the number on the sole, and a
// list that cannot tell their 7-iron from their 4-iron is a list they cannot
// use.
//
// The number comes from the loft, because the loft is the club: one maker's
// 7-iron is another's 6, and the number stamped on the sole is a marketing
// decision. Two clubs of the same loft play the same distance whatever is
// printed on them.
//
// This mirrors StandardBag.nameFor on the server, which names the clubs in the
// hole advice. Deliberately duplicated rather than fetched: the bag works
// offline, and a club a golfer just added has to have a name before it has
// been anywhere near the API.

import '../data/bag_dto.dart';

abstract final class ClubNaming {
  /// Loft in degrees → the number a golfer would say, per club type.
  ///
  /// The lofts are the standard set the server seeds. A club within tolerance
  /// of one of these is that club.
  static const Map<ClubType, List<(double, String)>> _byLoft = {
    ClubType.wood: [(15.0, 'Gỗ 3'), (18.0, 'Gỗ 5'), (21.0, 'Gỗ 7')],
    ClubType.hybrid: [(19.0, 'Hybrid 3'), (21.0, 'Hybrid 4'), (24.0, 'Hybrid 5')],
    ClubType.iron: [
      (18.0, 'Sắt 2'),
      (21.0, 'Sắt 3'),
      (24.0, 'Sắt 4'),
      (27.0, 'Sắt 5'),
      (30.0, 'Sắt 6'),
      (34.0, 'Sắt 7'),
      (38.0, 'Sắt 8'),
      (42.0, 'Sắt 9'),
    ],
    ClubType.wedge: [
      (46.0, 'Pitching wedge'),
      (50.0, 'Gap wedge'),
      (54.0, 'Sand wedge'),
      (58.0, 'Lob wedge'),
    ],
  };

  /// Neighbouring irons sit three or four degrees apart, so a club within two
  /// of a standard loft is that club. Anything further out is one the standard
  /// set does not describe — a golfer's own driving iron — and keeps its type
  /// rather than being forced into the nearest name.
  static const double _tolerance = 2.0;

  /// What to call this club: "Sắt 7" where the loft says so, the plain type
  /// where it does not.
  static String name(ClubType type, double? loft) {
    if (loft == null) {
      return _plain(type);
    }
    final candidates = _byLoft[type];
    if (candidates == null) {
      return _plain(type);
    }

    String? best;
    var closest = double.infinity;
    for (final (standardLoft, label) in candidates) {
      final gap = (standardLoft - loft).abs();
      if (gap < closest) {
        closest = gap;
        best = label;
      }
    }
    return closest <= _tolerance && best != null ? best : _plain(type);
  }

  static String _plain(ClubType type) {
    switch (type) {
      case ClubType.driver:
        return 'Driver';
      case ClubType.wood:
        return 'Gỗ';
      case ClubType.hybrid:
        return 'Hybrid';
      case ClubType.iron:
        return 'Sắt';
      case ClubType.wedge:
        return 'Wedge';
      case ClubType.putter:
        return 'Gậy putt';
    }
  }
}

extension ClubNamed on ClubDTO {
  /// The name a golfer would use for this club.
  String get displayName => ClubNaming.name(clubType, loft);
}
