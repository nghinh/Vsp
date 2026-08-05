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

  /// Formats canonical metres for display, e.g. `152 m` / `166 yd`.
  static String format(double meters, DistanceUnit unit) =>
      '${displayValue(meters, unit)} ${suffix(unit)}';

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
