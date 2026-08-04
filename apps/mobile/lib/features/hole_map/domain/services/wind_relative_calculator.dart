// WindRelativeCalculator — VSP Mobile App
//
// Derives head/tail/crosswind components from WindEntity and shot line bearing.
//
// Shot line bearing convention: 0° = North, 90° = East, 180° = South, 270° = West.
// Wind direction convention (from WindEntity): 0° = North, 90° = East, clockwise.
//
// The calculation projects the wind vector onto the shot line axis:
//   - Headwind component: wind dot shot-line-unit-vector (positive = into face)
//   - Crosswind component: wind dot perpendicular-unit-vector (positive = from left)
//
// Example: shot to North (0°), wind from North (0°) → full headwind (negative).
// Example: shot to North (0°), wind from South (180°) → full tailwind (positive).
// Example: shot to North (0°), wind from East (90°) → full crosswind-right (negative).

import 'dart:math' as math;

import '../wind_entity.dart';
import '../wind_relative_entity.dart';
import 'wind_staleness_guard.dart';

/// Calculates wind components relative to the shot line.
class WindRelativeCalculator {
  /// Maximum age for wind data before it is considered stale (default 30 min).
  final Duration maxAge;

  WindRelativeCalculator({this.maxAge = const Duration(minutes: 30)});

  /// Calculates wind components relative to a shot line.
  ///
  /// [wind] — the source wind data with direction (degrees, 0=North, clockwise)
  ///           and speed (km/h).
  /// [shotLineBearingDegrees] — direction from golfer to target/pin, in degrees,
  ///           0 = North, clockwise (0–360).
  ///
  /// Returns [WindRelativeEntity] with components or a null-result entity if
  /// the wind is stale or missing. Returns null only when [wind] is null.
  WindRelativeEntity? calculate({
    required WindEntity wind,
    required double shotLineBearingDegrees,
    Duration? maxAge,
  }) {
    if (wind == null) return null;

    final effectiveMaxAge = maxAge ?? this.maxAge;
    final stale = isWindStale(wind, maxAge: effectiveMaxAge);

    if (stale) {
      return WindRelativeEntity(
        source: wind.source,
        timestamp: wind.timestamp,
        isStale: true,
        confidence: 0.0,
      );
    }

    final windDirRad = _degreesToRadians(wind.direction);
    final shotRad = _degreesToRadians(shotLineBearingDegrees);

    // Shot line unit vector (x = east, y = north in math convention)
    final shotX = math.sin(shotRad);
    final shotY = math.cos(shotRad);

    // Perpendicular (90° clockwise from shot line)
    final perpX = math.cos(shotRad); // sin(shot + 90°)
    final perpY = -math.sin(shotRad); // -cos(shot + 90°)

    // Wind vector components (x = east, y = north)
    final windX = wind.speed * math.sin(windDirRad);
    final windY = wind.speed * math.cos(windDirRad);

    // Project wind onto shot line axis:
    // Dot product gives component along that axis.
    // Positive along shot axis = tailwind (at back)
    // Positive across axis = from left (pushes ball right? careful with sign)
    //
    // Convention:
    //   headwind  > 0: wind opposes shot direction (blows into face)
    //   tailwind  > 0: wind helps at back
    //   crosswindLeft > 0: wind from left side
    //   crosswindRight > 0: wind from right side
    //
    // Derivation:
    //   wind_along_shot = wind · shot_unit  (positive = tailwind)
    //   headwind = -wind_along_shot        (positive = into face)
    //
    //   wind_across_shot = wind · perp_unit (positive = from right)
    //   crosswindLeft    = -wind_across_shot (positive = from left)

    final windAlongShot = windX * shotX + windY * shotY;
    final windAcrossShot = windX * perpX + windY * perpY;

    // headwind > 0 means wind into face (opposite to shot)
    final headwind = -windAlongShot;
    // tailwind > 0 means wind at back (same direction as shot)
    final tailwind = windAlongShot;
    // crosswindLeft > 0 means wind from left
    final crosswindLeft = -windAcrossShot;
    // crosswindRight > 0 means wind from right
    final crosswindRight = windAcrossShot;

    // Confidence degrades slightly with age
    final ageMinutes = DateTime.now()
        .difference(wind.timestamp)
        .inMinutes
        .toDouble();
    final confidence = _computeConfidence(ageMinutes, effectiveMaxAge);

    return WindRelativeEntity(
      headwind: headwind,
      tailwind: tailwind,
      crosswindLeft: crosswindLeft,
      crosswindRight: crosswindRight,
      source: wind.source,
      timestamp: wind.timestamp,
      isStale: false,
      confidence: confidence,
    );
  }

  /// Computes confidence based on wind data age.
  /// Returns 1.0 for fresh data, decreasing linearly to 0.5 at maxAge.
  double _computeConfidence(double ageMinutes, Duration maxAge) {
    final maxAgeMinutes = maxAge.inMinutes.toDouble();
    if (maxAgeMinutes <= 0) return 0.0;

    final freshness = 1.0 - (ageMinutes / maxAgeMinutes).clamp(0.0, 1.0);
    // Map [0, 1] → [0.5, 1.0]
    return 0.5 + (freshness * 0.5);
  }

  /// Returns the angle difference in degrees, handling 0°/360° wrap-around.
  ///
  /// Result is in range (-180, 180] where:
  ///   - positive = wind is clockwise from shot line
  ///   - negative = wind is counter-clockwise from shot line
  double angleDifference(double windDirDegrees, double shotLineDegrees) {
    final diff = windDirDegrees - shotLineDegrees;
    return _normalizeAngleDiff(diff);
  }

  double _normalizeAngleDiff(double diff) {
    // Normalize to (-180, 180]
    var result = diff % 360;
    if (result > 180) result -= 360;
    if (result <= -180) result += 360;
    return result;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}
