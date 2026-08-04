// Distance Measurement Value Object — VSP Mobile App
//
// A single distance measurement with full metadata.
// Canonical storage is always meters.
//
// Story 6.4 — Wave 1: Domain models

import 'package:equatable/equatable.dart';

import 'distance_type.dart';

/// Data source classification for a distance measurement.
enum DistanceSource {
  /// Official course data (Class A/B verified).
  official('Official'),

  /// Estimated or community data (Class C/D or unverified).
  estimated('Estimated');

  final String displayName;
  const DistanceSource(this.displayName);
}

/// A single distance measurement with metadata.
//
// All distances are stored in canonical METERS.
// Conversion to yards happens at the display layer.
class DistanceMeasurement extends Equatable {
  /// Distance value in canonical meters.
  final double valueMeters;

  /// Type of distance (front/center/back green, bunker, water, etc.).
  final DistanceType type;

  /// Source of the data (official/estimated).
  final DistanceSource source;

  /// When this measurement was calculated.
  final DateTime? timestamp;

  /// GPS accuracy in meters at the time of calculation.
  final double gpsAccuracyMeters;

  /// Confidence score 0.0–1.0 derived from GPS accuracy + data quality.
  final double confidence;

  /// True if this measurement includes elevation adjustment.
  final bool hasElevationAdjustment;

  const DistanceMeasurement({
    required this.valueMeters,
    required this.type,
    required this.source,
    required this.timestamp,
    required this.gpsAccuracyMeters,
    required this.confidence,
    this.hasElevationAdjustment = false,
  });

  // ─── Construction helpers ───────────────────────────────────────────────────

  /// Create an official-distance measurement.
  factory DistanceMeasurement.official({
    required double meters,
    required DistanceType type,
    required DateTime timestamp,
    required double gpsAccuracyMeters,
    double confidence = 1.0,
    bool hasElevation = false,
  }) {
    return DistanceMeasurement(
      valueMeters: meters,
      type: type,
      source: DistanceSource.official,
      timestamp: timestamp,
      gpsAccuracyMeters: gpsAccuracyMeters,
      confidence: confidence,
      hasElevationAdjustment: hasElevation,
    );
  }

  /// Create an estimated-distance measurement.
  factory DistanceMeasurement.estimated({
    required double meters,
    required DistanceType type,
    required DateTime timestamp,
    required double gpsAccuracyMeters,
    double confidence = 0.7,
    bool hasElevation = false,
  }) {
    return DistanceMeasurement(
      valueMeters: meters,
      type: type,
      source: DistanceSource.estimated,
      timestamp: timestamp,
      gpsAccuracyMeters: gpsAccuracyMeters,
      confidence: confidence,
      hasElevationAdjustment: hasElevation,
    );
  }

  // ─── Unit conversion ─────────────────────────────────────────────────────────

  /// Meters-to-yards conversion factor.
  static const double _metersToYards = 1.09361;

  /// Value in yards.
  double get valueYards => valueMeters * _metersToYards;

  /// Format as integer meters string, e.g. "152 m".
  String formatMeters() => '${valueMeters.round()} m';

  /// Format as integer yards string, e.g. "166 yd".
  String formatYards() => '${valueYards.round()} yd';

  /// Format in the given unit.
  String format({required bool useYards}) =>
      useYards ? formatYards() : formatMeters();

  /// Display value in the requested unit.
  double displayValue({required bool useYards}) =>
      useYards ? valueYards : valueMeters;

  /// Unit label for display.
  String unitLabel({required bool useYards}) => useYards ? 'yd' : 'm';

  // ─── GPS accuracy helpers ────────────────────────────────────────────────────

  /// GPS accuracy level for color coding.
  GpsAccuracyLevel get accuracyLevel {
    if (gpsAccuracyMeters < 5) return GpsAccuracyLevel.excellent;
    if (gpsAccuracyMeters < 10) return GpsAccuracyLevel.good;
    if (gpsAccuracyMeters < 20) return GpsAccuracyLevel.moderate;
    return GpsAccuracyLevel.poor;
  }

  /// True if GPS accuracy is acceptable for on-course use.
  bool get isAccurate => gpsAccuracyMeters <= 10;

  /// True if GPS accuracy warrants a warning (>= 10m).
  bool get hasAccuracyWarning => gpsAccuracyMeters >= 10;

  /// True if GPS accuracy is too poor for reliable distance (>= 20m).
  bool get isAccuracyPoor => gpsAccuracyMeters >= 20;

  // ─── Confidence helpers ─────────────────────────────────────────────────────

  /// Confidence level label.
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.9) return ConfidenceLevel.high;
    if (confidence >= 0.7) return ConfidenceLevel.medium;
    if (confidence >= 0.5) return ConfidenceLevel.low;
    return ConfidenceLevel.veryLow;
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  /// Parse from JSON (e.g. stored offline or from API).
  factory DistanceMeasurement.fromJson(Map<String, dynamic> json) {
    return DistanceMeasurement(
      valueMeters: (json['valueMeters'] as num).toDouble(),
      type: DistanceType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => DistanceType.pin,
      ),
      source: DistanceSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => DistanceSource.estimated,
      ),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      gpsAccuracyMeters: (json['gpsAccuracyMeters'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      hasElevationAdjustment: json['hasElevationAdjustment'] as bool? ?? false,
    );
  }

  /// Serialize to JSON for offline storage.
  Map<String, dynamic> toJson() => {
    'valueMeters': valueMeters,
    'type': type.name,
    'source': source.name,
    'timestamp': timestamp?.toIso8601String(),
    'gpsAccuracyMeters': gpsAccuracyMeters,
    'confidence': confidence,
    'hasElevationAdjustment': hasElevationAdjustment,
  };

  /// Human-readable description.
  String get description => '${type.displayName}: ${formatMeters()}';

  @override
  List<Object?> get props => [
    valueMeters,
    type,
    source,
    timestamp,
    gpsAccuracyMeters,
    confidence,
    hasElevationAdjustment,
  ];
}

/// GPS accuracy color levels.
enum GpsAccuracyLevel {
  excellent, // < 5m — green
  good, // 5–10m — green/amber
  moderate, // 10–20m — amber
  poor, // >= 20m — red
}

/// Confidence level labels.
enum ConfidenceLevel {
  high, // >= 0.9
  medium, // 0.7–0.89
  low, // 0.5–0.69
  veryLow, // < 0.5
}
