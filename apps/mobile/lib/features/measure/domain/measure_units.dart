// Measure Units — VSP Mobile App
//
// Canonical storage is always metres (as everywhere else in the app);
// conversion to the golfer's preferred unit happens at the display layer only.

import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Unit conversion and formatting for measuring-tool distances.
abstract final class MeasureUnits {
  /// Metres-to-yards factor. Matches [DistanceMeasurement] so a distance never
  /// changes depending on which widget renders it.
  static const double metersToYards = 1.09361;

  /// Converts canonical metres to [unit].
  static double convert(double meters, DistanceUnit unit) =>
      unit == DistanceUnit.yards ? meters * metersToYards : meters;

  /// Short unit suffix — `m` or `yd`.
  static String suffix(DistanceUnit unit) =>
      unit == DistanceUnit.yards ? 'yd' : 'm';

  /// Rounded display value in [unit].
  static int displayValue(double meters, DistanceUnit unit) =>
      convert(meters, unit).round();

  /// Beyond this, a "distance to the green" is not a golf distance.
  ///
  /// The longest hole ever played is under 1 km, so anything past a few
  /// kilometres means the golfer is not on the course — checking tomorrow's
  /// round from home, most likely. Worth naming, because the alternative is
  /// what this app used to print.
  static const double offCourseThresholdMeters = 3000;

  /// True when [meters] is too far to be a distance on a golf hole.
  static bool isOffCourse(double meters) =>
      meters.abs() >= offCourseThresholdMeters;

  /// Formats canonical metres for display, e.g. `152 m` / `166 yd`.
  ///
  /// Distances past [offCourseThresholdMeters] switch to kilometres. Opening
  /// the app in Hà Nội with a round set at Long Thành rendered the distance to
  /// the green as `1135481 m` — seven digits, unreadable at a glance, and
  /// indistinguishable from a broken calculation. It was in fact exactly right,
  /// which is the problem: a correct number nobody can read teaches the golfer
  /// to distrust the ones they can.
  ///
  /// [rollOverAt] overrides where the switch to kilometres or miles happens,
  /// in metres. The default suits a distance on a hole; a travel distance to a
  /// course wants a lower one, because "1523 m away" is a number a golfer has
  /// to divide before it means anything, while "1.5 km" is a drive.
  static String format(double meters, DistanceUnit unit, {double? rollOverAt}) {
    if (meters.abs() >= (rollOverAt ?? offCourseThresholdMeters)) {
      // Stay in the golfer's own system of units — a yards user reading
      // kilometres has to convert twice to picture the distance.
      final large = unit == DistanceUnit.yards
          ? convert(meters, unit) / 1760
          : meters / 1000;
      final label = unit == DistanceUnit.yards ? 'mi' : 'km';
      return '${large < 10 ? large.toStringAsFixed(1) : large.round()} $label';
    }
    return '${displayValue(meters, unit)} ${suffix(unit)}';
  }

  /// Formats a value that is already in yards, for the golfer's own unit.
  ///
  /// The shot-analytics models come off the API in yards — `averageDistanceYards`
  /// and its neighbours — so they cannot go through [format] without first
  /// coming back to canonical metres. Naming that round trip here keeps the
  /// factor in one place; the alternative was each chart dividing by 1.09361
  /// inline, which is how three of them ended up not converting at all.
  static String formatYards(double yards, DistanceUnit unit) =>
      format(yards / metersToYards, unit);

  /// Formats an uncertainty as a signed tolerance, e.g. `±12 m`.
  ///
  /// Always rounds up: a tolerance that rounds down reads as more precision
  /// than we have.
  static String formatTolerance(double meters, DistanceUnit unit) {
    final converted = convert(meters, unit);
    return '±${converted.ceil()} ${suffix(unit)}';
  }

  /// True when the golfer's preference is yards.
  static bool useYards(DistanceUnit unit) => unit == DistanceUnit.yards;
}
