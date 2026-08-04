// WindStalenessGuard — VSP Mobile App
//
// Determines whether wind data is too old to produce reliable calculations.
// Used as a gate before displaying or using wind components.
//
// When wind is stale:
//   - WindRelativeCalculator.calculate() returns an entity with all null
//     components and confidence = 0.0
//   - UI shows "Wind stale" instead of fabricated numbers

import '../wind_entity.dart';

/// Default maximum acceptable age for wind data (30 minutes).
const defaultWindMaxAge = Duration(minutes: 30);

/// Returns true when [wind] data is older than [maxAge].
///
/// Stale wind must not be displayed as precision data — doing so would
/// violate the "no fabricated precision" product principle.
bool isWindStale(WindEntity wind, {Duration maxAge = defaultWindMaxAge}) {
  final age = DateTime.now().difference(wind.timestamp);
  return age.inSeconds > maxAge.inSeconds;
}

/// Returns the age of wind data as a [Duration].
Duration getWindAge(WindEntity wind) {
  return DateTime.now().difference(wind.timestamp);
}

/// Returns a human-readable description of wind freshness.
WindFreshness describeWindFreshness(
  WindEntity wind, {
  Duration maxAge = defaultWindMaxAge,
}) {
  final age = getWindAge(wind);

  if (age <= const Duration(minutes: 5)) {
    return WindFreshness.fresh;
  } else if (age <= maxAge) {
    return WindFreshness.current;
  } else if (age <= maxAge * 2) {
    return WindFreshness.stale;
  } else {
    return WindFreshness.veryStale;
  }
}

/// Describes how fresh the wind data is.
enum WindFreshness {
  /// Wind data is less than 5 minutes old.
  fresh,

  /// Wind data is within acceptable range but not brand new.
  current,

  /// Wind data is older than maxAge but less than 2× maxAge.
  stale,

  /// Wind data is very stale (more than 2× maxAge).
  veryStale,
}
