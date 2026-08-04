// WindEntity — VSP Mobile App
//
// Wind conditions for the current hole.

import 'package:equatable/equatable.dart';

/// Source of wind data (official weather or on-device estimation).
enum WindSource { official, onDevice, manual }

/// Wind direction and speed for shot planning.
class WindEntity extends Equatable {
  final double direction; // degrees, 0 = North, clockwise
  final double speed; // km/h or m/s — annotate in UI
  final WindSource source;
  final DateTime timestamp;
  final String? unit;

  const WindEntity({
    required this.direction,
    required this.speed,
    required this.source,
    required this.timestamp,
    this.unit,
  });

  /// Returns wind direction as a cardinal compass direction.
  String get cardinalDirection {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    final index = ((direction + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  WindEntity copyWith({
    double? direction,
    double? speed,
    WindSource? source,
    DateTime? timestamp,
    String? unit,
  }) {
    return WindEntity(
      direction: direction ?? this.direction,
      speed: speed ?? this.speed,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      unit: unit ?? this.unit,
    );
  }

  @override
  List<Object?> get props => [direction, speed, source, timestamp, unit];
}
