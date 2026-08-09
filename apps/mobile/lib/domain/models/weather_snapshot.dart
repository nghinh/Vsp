// WeatherSnapshot — VSP Mobile App
//
// Story 7.1 Wave 2: Mobile Domain Model
// AC-1: Mobile shows wind direction/speed/gust, temperature, precipitation, safety fields.
// AC-3: Source, timestamp, forecast/measurement type, stale warning, offline snapshot visible.
//
// Immutable once constructed. All fields are non-null unless explicitly nullable
// per the WeatherSnapshot contract from packages/contracts/schemas/weather.yaml.

import 'package:equatable/equatable.dart';

import 'qualified_location.dart';
import 'wind_data.dart';

/// Weather condition enum — mirrors backend condition enum and weather.yaml.
enum WeatherCondition {
  sunny,
  partly_cloudy,
  cloudy,
  overcast,
  light_rain,
  rain,
  heavy_rain,
  thunderstorm,
  fog,
  windy;

  /// Parse from API string value.
  static WeatherCondition fromString(String? value) {
    if (value == null) return WeatherCondition.sunny;
    return WeatherCondition.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => WeatherCondition.sunny,
    );
  }

  /// Human-readable display label.
  String get displayLabel {
    switch (this) {
      case WeatherCondition.sunny:
        return 'Sunny';
      case WeatherCondition.partly_cloudy:
        return 'Partly Cloudy';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.overcast:
        return 'Overcast';
      case WeatherCondition.light_rain:
        return 'Light Rain';
      case WeatherCondition.rain:
        return 'Rain';
      case WeatherCondition.heavy_rain:
        return 'Heavy Rain';
      case WeatherCondition.thunderstorm:
        return 'Thunderstorm';
      case WeatherCondition.fog:
        return 'Fog';
      case WeatherCondition.windy:
        return 'Windy';
    }
  }
}

/// Measurement type: forecast (predicted) or measured (actual observation).
enum MeasurementType {
  /// Current/measured weather observation.
  measured,

  /// Forecast/predicted weather.
  forecast;

  static MeasurementType fromBool(bool isForecast) =>
      isForecast ? MeasurementType.forecast : MeasurementType.measured;

  bool get isForecast => this == MeasurementType.forecast;
}

/// Data freshness state for UI display.
enum DataFreshness {
  /// Data is current and within TTL.
  fresh,

  /// Data is older than TTL but still usable with a warning.
  stale,

  /// Data has expired and should not be displayed as current.
  expired;

  /// Derive freshness from expiresAt timestamp.
  static DataFreshness fromExpiresAt(DateTime? expiresAt) {
    if (expiresAt == null) return DataFreshness.stale;
    final now = DateTime.now();
    if (now.isBefore(expiresAt)) return DataFreshness.fresh;
    // Check if expired within 2x the TTL (1 hour from now for 30min TTL)
    if (now.isBefore(expiresAt.add(const Duration(hours: 1)))) {
      return DataFreshness.stale;
    }
    return DataFreshness.expired;
  }
}

/// Verification status of weather data.
enum WeatherVerificationStatus {
  official,
  community,
  estimated;

  static WeatherVerificationStatus fromString(String? value) {
    if (value == null) return WeatherVerificationStatus.estimated;
    return WeatherVerificationStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => WeatherVerificationStatus.estimated,
    );
  }

  String get displayLabel {
    switch (this) {
      case WeatherVerificationStatus.official:
        return 'Official';
      case WeatherVerificationStatus.community:
        return 'Community';
      case WeatherVerificationStatus.estimated:
        return 'Estimated';
    }
  }
}

/// Temperature value object with unit.
class Temperature extends Equatable {
  final double value;
  final String unit; // 'C' or 'F'

  const Temperature({required this.value, required this.unit});

  factory Temperature.fromJson(Map<String, dynamic> json) {
    return Temperature(
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'C',
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'unit': unit};

  /// Temperature in Celsius (converts if needed).
  double get celsius => unit == 'C' ? value : (value - 32) * 5 / 9;

  /// Temperature in Fahrenheit (converts if needed).
  double get fahrenheit => unit == 'F' ? value : value * 9 / 5 + 32;

  @override
  List<Object?> get props => [value, unit];
}

/// Visibility value object with unit.
class Visibility extends Equatable {
  final double value;
  final String unit; // 'km' or 'mi'

  const Visibility({required this.value, required this.unit});

  factory Visibility.fromJson(Map<String, dynamic> json) {
    return Visibility(
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'km',
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'unit': unit};

  /// Visibility in kilometers.
  double get kilometers => unit == 'km' ? value : value * 1.60934;

  @override
  List<Object?> get props => [value, unit];
}

/// Pressure value object with unit.
class Pressure extends Equatable {
  final double value;
  final String unit; // 'hPa' or 'inHg'

  const Pressure({required this.value, required this.unit});

  factory Pressure.fromJson(Map<String, dynamic> json) {
    return Pressure(
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'hPa',
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'unit': unit};

  /// Pressure in hPa.
  double get hpa => unit == 'hPa' ? value : value * 33.8639;

  @override
  List<Object?> get props => [value, unit];
}

/// Weather source metadata for UI display.
class WeatherSource extends Equatable {
  final String name; // display name, e.g. "OpenWeatherMap"
  final String provider; // machine name, e.g. "openweathermap"
  final MeasurementType measurementType;
  final WeatherVerificationStatus verificationStatus;
  final double? confidence; // 0.0–1.0
  final String? accuracyClass; // 'A', 'B', 'C', 'D'

  const WeatherSource({
    required this.name,
    required this.provider,
    required this.measurementType,
    required this.verificationStatus,
    this.confidence,
    this.accuracyClass,
  });

  factory WeatherSource.fromJson(Map<String, dynamic> json) {
    return WeatherSource(
      name:
          json['sourceName'] as String? ??
          json['source_name'] as String? ??
          'Unknown',
      provider: json['provider'] as String? ?? 'unknown',
      measurementType: MeasurementType.fromBool(
        json['isForecast'] as bool? ?? false,
      ),
      verificationStatus: WeatherVerificationStatus.fromString(
        json['verificationStatus'] as String?,
      ),
      confidence: (json['confidence'] as num?)?.toDouble(),
      accuracyClass: json['accuracyClass'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'sourceName': name,
    'provider': provider,
    'isForecast': measurementType.isForecast,
    'verificationStatus': verificationStatus.name,
    if (confidence != null) 'confidence': confidence,
    if (accuracyClass != null) 'accuracyClass': accuracyClass,
  };

  /// Human-readable source label.
  String get displayLabel {
    final type = measurementType == MeasurementType.forecast
        ? 'Forecast'
        : 'Current';
    return '$name ($type)';
  }

  @override
  List<Object?> get props => [
    name,
    provider,
    measurementType,
    verificationStatus,
    confidence,
    accuracyClass,
  ];
}

/// Complete weather snapshot for a location.
//
// AC-1: wind, temperature, precipitation, safety fields.
// AC-3: source, timestamp, forecast/measurement type, stale warning.
class WeatherSnapshot extends Equatable {
  final String id;
  final DateTime timestamp;
  final QualifiedLocation location;
  final Temperature? temperature;
  final int? humidity;
  final WeatherCondition condition;
  final WindData wind;
  final Visibility? visibility;
  final Pressure? pressure;
  final int? uvIndex;
  final double? feelsLike;
  final int? precipitationProbability;
  final WeatherSource source;
  final DataFreshness freshness;
  final DateTime? expiresAt;

  const WeatherSnapshot({
    required this.id,
    required this.timestamp,
    required this.location,
    this.temperature,
    this.humidity,
    required this.condition,
    required this.wind,
    this.visibility,
    this.pressure,
    this.uvIndex,
    this.feelsLike,
    this.precipitationProbability,
    required this.source,
    required this.freshness,
    this.expiresAt,
  });

  /// Parse from API JSON response (WeatherSnapshotDto shape).
  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final capturedAt = json['capturedAt'] != null
        ? DateTime.parse(json['capturedAt'] as String)
        : json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now();
    final expiresAt = json['expiresAt'] != null
        ? DateTime.parse(json['expiresAt'] as String)
        : null;

    return WeatherSnapshot(
      id: json['id'] as String? ?? '',
      timestamp: capturedAt,
      location: QualifiedLocation(
        latitude: (json['location']?['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['location']?['longitude'] as num?)?.toDouble() ?? 0,
        timestamp: capturedAt,
        source: LocationSource.gps,
        isStale: false,
      ),
      temperature: json['temperature'] != null
          ? Temperature.fromJson(json['temperature'] as Map<String, dynamic>)
          : null,
      humidity: (json['humidity'] as num?)?.toInt(),
      condition: WeatherCondition.fromString(json['condition'] as String?),
      wind: json['wind'] != null
          ? WindData.fromJson(json['wind'] as Map<String, dynamic>)
          : const WindData(
              speed: 0,
              unit: WindSpeedUnit.kmh,
              direction: WindDirection.n,
              degrees: 0,
            ),
      visibility: json['visibility'] != null
          ? Visibility.fromJson(json['visibility'] as Map<String, dynamic>)
          : null,
      pressure: json['pressure'] != null
          ? Pressure.fromJson(json['pressure'] as Map<String, dynamic>)
          : null,
      uvIndex: (json['uvIndex'] as num?)?.toInt(),
      feelsLike: (json['feelsLike'] as num?)?.toDouble(),
      precipitationProbability: (json['precipitationProbability'] as num?)
          ?.toInt(),
      source: WeatherSource.fromJson(json),
      freshness: DataFreshness.fromExpiresAt(expiresAt),
      expiresAt: expiresAt,
    );
  }

  /// Serialize to JSON for caching.
  Map<String, dynamic> toJson() => {
    'id': id,
    'capturedAt': timestamp.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'timestamp': timestamp.toUtc().toIso8601String(),
    'location': {
      'latitude': location.latitude,
      'longitude': location.longitude,
    },
    if (temperature != null) 'temperature': temperature!.toJson(),
    'humidity': humidity,
    'condition': condition.name,
    'wind': wind.toJson(),
    if (visibility != null) 'visibility': visibility!.toJson(),
    if (pressure != null) 'pressure': pressure!.toJson(),
    'uvIndex': uvIndex,
    'feelsLike': feelsLike,
    'precipitationProbability': precipitationProbability,
    ...source.toJson(),
  };

  /// Relative time string for UI: "Updated 5 min ago".
  String get relativeTimeString {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated ${diff.inDays}d ago';
  }

  /// True if this snapshot shows forecast data as current measurement
  /// (should be flagged in UI per slice plan §3.3).
  bool get isMisrepresentedForecast =>
      source.measurementType == MeasurementType.forecast &&
      freshness == DataFreshness.stale;

  WeatherSnapshot copyWith({
    String? id,
    DateTime? timestamp,
    QualifiedLocation? location,
    Temperature? temperature,
    int? humidity,
    WeatherCondition? condition,
    WindData? wind,
    Visibility? visibility,
    Pressure? pressure,
    int? uvIndex,
    double? feelsLike,
    int? precipitationProbability,
    WeatherSource? source,
    DataFreshness? freshness,
    DateTime? expiresAt,
  }) {
    return WeatherSnapshot(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      condition: condition ?? this.condition,
      wind: wind ?? this.wind,
      visibility: visibility ?? this.visibility,
      pressure: pressure ?? this.pressure,
      uvIndex: uvIndex ?? this.uvIndex,
      feelsLike: feelsLike ?? this.feelsLike,
      precipitationProbability:
          precipitationProbability ?? this.precipitationProbability,
      source: source ?? this.source,
      freshness: freshness ?? this.freshness,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    timestamp,
    location,
    temperature,
    humidity,
    condition,
    wind,
    visibility,
    pressure,
    uvIndex,
    feelsLike,
    precipitationProbability,
    source,
    freshness,
    expiresAt,
  ];
}
