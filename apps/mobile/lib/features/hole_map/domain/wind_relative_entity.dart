// WindRelativeEntity — VSP Mobile App
//
// Wind components (head/tail/crosswind) derived from shot line bearing.
// Produced by WindRelativeCalculator from WindEntity + shot line.

import 'package:equatable/equatable.dart';

import 'wind_entity.dart';

/// Component label describing which wind axis is being represented.
enum WindComponentLabel {
  /// Headwind component: wind blowing into the face of the shot.
  headwind,

  /// Tailwind component: wind at the back of the shot.
  tailwind,

  /// Crosswind from the left (pushes ball left).
  crosswindLeft,

  /// Crosswind from the right (pushes ball right).
  crosswindRight,
}

/// Wind components relative to the shot line bearing.
///
/// Derived by projecting the absolute wind vector onto the shot line axis:
/// - headwind: positive when wind blows opposite to shot direction (into face)
/// - tailwind: positive when wind blows with the shot direction (at back)
/// - crosswindLeft: positive when wind pushes from the left
/// - crosswindRight: positive when wind pushes from the right
///
/// All component values are in the same unit as the source wind speed (km/h).
/// Null components indicate missing source data or stale wind.
class WindRelativeEntity extends Equatable {
  /// Headwind component in km/h. Positive = into face, negative = tailwind help.
  final double? headwind;

  /// Tailwind component in km/h. Positive = at back, negative = headwind.
  final double? tailwind;

  /// Crosswind from the left in km/h. Positive = pushes ball left.
  final double? crosswindLeft;

  /// Crosswind from the right in km/h. Positive = pushes ball right.
  final double? crosswindRight;

  /// Source of the underlying wind data.
  final WindSource source;

  /// Timestamp of the wind data used for this calculation.
  final DateTime timestamp;

  /// True when wind data is older than the configured max age.
  final bool isStale;

  /// Confidence of this calculation. 0.0 when stale or missing data.
  final double? confidence;

  const WindRelativeEntity({
    this.headwind,
    this.tailwind,
    this.crosswindLeft,
    this.crosswindRight,
    required this.source,
    required this.timestamp,
    this.isStale = false,
    this.confidence,
  });

  /// Returns the dominant component label, if any component is non-null.
  WindComponentLabel? get dominantComponent {
    final components = {
      WindComponentLabel.headwind: headwind ?? double.negativeInfinity,
      WindComponentLabel.tailwind: tailwind ?? double.negativeInfinity,
      WindComponentLabel.crosswindLeft:
          crosswindLeft ?? double.negativeInfinity,
      WindComponentLabel.crosswindRight:
          crosswindRight ?? double.negativeInfinity,
    };

    final maxEntry = components.entries.reduce(
      (a, b) => a.value.abs() > b.value.abs() ? a : b,
    );

    if (maxEntry.value == double.negativeInfinity) return null;
    return maxEntry.key;
  }

  /// Human-readable description of the dominant component.
  String? get dominantComponentLabel {
    final dominant = dominantComponent;
    if (dominant == null) return null;

    switch (dominant) {
      case WindComponentLabel.headwind:
        return 'Headwind';
      case WindComponentLabel.tailwind:
        return 'Tailwind';
      case WindComponentLabel.crosswindLeft:
        return 'Crosswind from left';
      case WindComponentLabel.crosswindRight:
        return 'Crosswind from right';
    }
  }

  /// True when all wind components are null.
  bool get hasNoComponents =>
      headwind == null &&
      tailwind == null &&
      crosswindLeft == null &&
      crosswindRight == null;

  WindRelativeEntity copyWith({
    double? headwind,
    double? tailwind,
    double? crosswindLeft,
    double? crosswindRight,
    WindSource? source,
    DateTime? timestamp,
    bool? isStale,
    double? confidence,
  }) {
    return WindRelativeEntity(
      headwind: headwind ?? this.headwind,
      tailwind: tailwind ?? this.tailwind,
      crosswindLeft: crosswindLeft ?? this.crosswindLeft,
      crosswindRight: crosswindRight ?? this.crosswindRight,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      isStale: isStale ?? this.isStale,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  List<Object?> get props => [
    headwind,
    tailwind,
    crosswindLeft,
    crosswindRight,
    source,
    timestamp,
    isStale,
    confidence,
  ];
}
