// WindData — VSP Mobile App
//
// Story 7.1 Wave 2: Mobile Domain Model
// AC-1: wind direction/speed/gust per PRD §8.9.
//
// Mirrors WindDataDto from backend and WindData schema from weather.yaml.
// Immutable once constructed.

import 'package:equatable/equatable.dart';

/// Wind speed unit.
enum WindSpeedUnit {
  kmh,
  mph,
  ms,
  knots;

  /// Parse from API string value.
  static WindSpeedUnit fromString(String? value) {
    if (value == null) return WindSpeedUnit.kmh;
    return WindSpeedUnit.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => WindSpeedUnit.kmh,
    );
  }

  /// Display label for the unit.
  String get displayLabel {
    switch (this) {
      case WindSpeedUnit.kmh:
        return 'km/h';
      case WindSpeedUnit.mph:
        return 'mph';
      case WindSpeedUnit.ms:
        return 'm/s';
      case WindSpeedUnit.knots:
        return 'kn';
    }
  }

  /// Convert speed to km/h.
  double toKmh(double value) {
    switch (this) {
      case WindSpeedUnit.kmh:
        return value;
      case WindSpeedUnit.mph:
        return value * 1.60934;
      case WindSpeedUnit.ms:
        return value * 3.6;
      case WindSpeedUnit.knots:
        return value * 1.852;
    }
  }
}

/// Wind direction as compass enum — 8 cardinal + 8 intercardinal directions.
enum WindDirection {
  n,
  nne,
  ne,
  ene,
  e,
  ese,
  se,
  sse,
  s,
  ssw,
  sw,
  wsw,
  w,
  wnw,
  nw,
  nnw;

  /// Parse from API string (N, NE, E, SE, S, SW, W, NW) or degrees.
  static WindDirection fromString(String? value) {
    if (value == null) return WindDirection.n;
    final normalized = value.toUpperCase().trim();
    return WindDirection.values.firstWhere(
      (e) =>
          e.name == normalized || _nameForCardinal(e, normalized) == normalized,
      orElse: () => WindDirection.n,
    );
  }

  /// Parse from degrees (0–360).
  static WindDirection fromDegrees(int? degrees) {
    if (degrees == null) return WindDirection.n;
    const directions = [
      WindDirection.n, // 0
      WindDirection.nne, // 22.5
      WindDirection.ne, // 45
      WindDirection.ene, // 67.5
      WindDirection.e, // 90
      WindDirection.ese, // 112.5
      WindDirection.se, // 135
      WindDirection.sse, // 157.5
      WindDirection.s, // 180
      WindDirection.ssw, // 202.5
      WindDirection.sw, // 225
      WindDirection.wsw, // 247.5
      WindDirection.w, // 270
      WindDirection.wnw, // 292.5
      WindDirection.nw, // 315
      WindDirection.nnw, // 337.5
    ];
    final index = ((degrees + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  static String _nameForCardinal(WindDirection d, String normalized) {
    const map = {
      'N': WindDirection.n,
      'NNE': WindDirection.nne,
      'NE': WindDirection.ne,
      'ENE': WindDirection.ene,
      'E': WindDirection.e,
      'ESE': WindDirection.ese,
      'SE': WindDirection.se,
      'SSE': WindDirection.sse,
      'S': WindDirection.s,
      'SSW': WindDirection.ssw,
      'SW': WindDirection.sw,
      'WSW': WindDirection.wsw,
      'W': WindDirection.w,
      'WNW': WindDirection.wnw,
      'NW': WindDirection.nw,
      'NNW': WindDirection.nnw,
    };
    for (final entry in map.entries) {
      if (entry.value == d) return entry.key;
    }
    return '';
  }

  /// Three-letter display label (N, NE, ENE, etc.).
  String get label {
    const labels = [
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
    return labels[index];
  }

  /// Compass degrees for this direction.
  double get degrees {
    return index * 22.5;
  }

  /// Full display name.
  String get displayName {
    const names = [
      'North',
      'North-Northeast',
      'Northeast',
      'East-Northeast',
      'East',
      'East-Southeast',
      'Southeast',
      'South-Southeast',
      'South',
      'South-Southwest',
      'Southwest',
      'West-Southwest',
      'West',
      'West-Northwest',
      'Northwest',
      'North-Northwest',
    ];
    return names[index];
  }
}

/// Wind data for a weather snapshot.
//
// AC-1: direction, speed, gusts per PRD §8.9.
class WindData extends Equatable {
  final double speed;
  final WindSpeedUnit unit;
  final WindDirection direction;
  final int degrees; // 0–360
  final double? gusts;

  const WindData({
    required this.speed,
    required this.unit,
    required this.direction,
    required this.degrees,
    this.gusts,
  });

  /// Parse from API JSON (WindDataDto shape).
  factory WindData.fromJson(Map<String, dynamic> json) {
    return WindData(
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      unit: WindSpeedUnit.fromString(json['unit'] as String?),
      direction: WindDirection.fromString(json['direction'] as String?),
      degrees: (json['degrees'] as num?)?.toInt() ?? 0,
      gusts: (json['gusts'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'speed': speed,
    'unit': unit.name,
    'direction': direction.label,
    'degrees': degrees,
    if (gusts != null) 'gusts': gusts,
  };

  /// Wind speed in km/h (converted if needed).
  double get speedKmh => unit.toKmh(speed);

  /// Gust speed in km/h (converted if needed).
  double? get gustsKmh => gusts != null ? unit.toKmh(gusts!) : null;

  /// Accessible wind labels are built in the UI via
  /// `AppLocalizations.weatherWindFromAt` so they follow the app language.

  WindData copyWith({
    double? speed,
    WindSpeedUnit? unit,
    WindDirection? direction,
    int? degrees,
    double? gusts,
  }) {
    return WindData(
      speed: speed ?? this.speed,
      unit: unit ?? this.unit,
      direction: direction ?? this.direction,
      degrees: degrees ?? this.degrees,
      gusts: gusts ?? this.gusts,
    );
  }

  @override
  List<Object?> get props => [speed, unit, direction, degrees, gusts];
}
