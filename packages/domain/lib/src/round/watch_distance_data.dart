// WatchDistanceData — VSP Domain Package
//
// Distance data contracts for Apple Watch display.
// Used to render the glanceable distance panel (FCB, pin, hazards).
//
// Story 10.1 — Slice 1: Watch Adapter & Data Contracts

import 'package:equatable/equatable.dart';

/// A single distance value with confidence metadata.
class WatchDistance extends Equatable {
  /// Distance in meters.
  final double meters;

  /// Confidence score 0.0–1.0.
  final double confidence;

  const WatchDistance({
    required this.meters,
    required this.confidence,
  });

  /// Distance in yards.
  double get yards => meters * 1.09361;

  /// Format for display given a unit preference.
  String format({required bool useYards}) =>
      useYards ? '${yards.round()} yd' : '${meters.round()} m';

  Map<String, dynamic> toJson() => {
        'meters': meters,
        'confidence': confidence,
      };

  factory WatchDistance.fromJson(Map<String, dynamic> json) => WatchDistance(
        meters: (json['meters'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [meters, confidence];
}

/// Hazard distance entry for watch display.
class WatchHazardDistance extends Equatable {
  /// Hazard type identifier.
  final String type; // 'bunker', 'water', 'ob', 'penalty'

  /// Short label for the hazard, e.g. "Lake 1".
  final String label;

  /// Distance to the hazard nearest point in meters.
  final double meters;

  /// Confidence score 0.0–1.0.
  final double confidence;

  /// Carry distance in meters (null if not applicable).
  final double? carryMeters;

  const WatchHazardDistance({
    required this.type,
    required this.label,
    required this.meters,
    required this.confidence,
    this.carryMeters,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'meters': meters,
        'confidence': confidence,
        if (carryMeters != null) 'carryMeters': carryMeters,
      };

  factory WatchHazardDistance.fromJson(Map<String, dynamic> json) =>
      WatchHazardDistance(
        type: json['type'] as String,
        label: json['label'] as String,
        meters: (json['meters'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        carryMeters: (json['carryMeters'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [type, label, meters, confidence, carryMeters];
}

/// Watch distance data — the data displayed on the watch distance panel.
///
/// This is computed from course geometry + GPS position and
/// sent to the watch app via the adapter layer.
class WatchDistanceData extends Equatable {
  /// Hole number.
  final int holeNumber;

  /// Par for this hole.
  final int par;

  /// Front green distance in meters.
  final WatchDistance frontGreen;

  /// Center green distance in meters.
  final WatchDistance centerGreen;

  /// Back green distance in meters.
  final WatchDistance backGreen;

  /// Pin/target distance in meters.
  final WatchDistance? pin;

  /// List of relevant hazards with distances.
  final List<WatchHazardDistance> hazards;

  /// Overall data confidence 0.0–1.0.
  final double confidence;

  /// GPS accuracy in meters at time of computation.
  final double gpsAccuracyMeters;

  /// Whether this is a live GPS position or last-known.
  final bool isLive;

  /// Timestamp when this data was computed.
  final DateTime computedAt;

  /// Hole length in meters (teeto green).
  final int? holeLengthMeters;

  const WatchDistanceData({
    required this.holeNumber,
    required this.par,
    required this.frontGreen,
    required this.centerGreen,
    required this.backGreen,
    this.pin,
    this.hazards = const [],
    required this.confidence,
    required this.gpsAccuracyMeters,
    this.isLive = true,
    required this.computedAt,
    this.holeLengthMeters,
  });

  /// Front-center-back tuple for display.
  List<WatchDistance> get fcb => [frontGreen, centerGreen, backGreen];

  /// Lowest confidence among all distances.
  double get lowestConfidence {
    var min = confidence;
    for (final d in [frontGreen, centerGreen, backGreen]) {
      if (d.confidence < min) min = d.confidence;
    }
    if (pin != null && pin!.confidence < min) min = pin!.confidence;
    for (final h in hazards) {
      if (h.confidence < min) min = h.confidence;
    }
    return min;
  }

  /// Whether GPS accuracy is acceptable for distance display.
  bool get isAccurate => gpsAccuracyMeters <= 10;

  /// Whether accuracy is poor enough to warrant a warning.
  bool get hasAccuracyWarning => gpsAccuracyMeters >= 10;

  /// Overall confidence level label.
  String get confidenceLabel {
    if (confidence >= 0.9) return 'High';
    if (confidence >= 0.7) return 'Medium';
    if (confidence >= 0.5) return 'Low';
    return 'Very Low';
  }

  Map<String, dynamic> toJson() => {
        'holeNumber': holeNumber,
        'par': par,
        'frontGreen': frontGreen.toJson(),
        'centerGreen': centerGreen.toJson(),
        'backGreen': backGreen.toJson(),
        if (pin != null) 'pin': pin!.toJson(),
        'hazards': hazards.map((h) => h.toJson()).toList(),
        'confidence': confidence,
        'gpsAccuracyMeters': gpsAccuracyMeters,
        'isLive': isLive,
        'computedAt': computedAt.toIso8601String(),
        if (holeLengthMeters != null) 'holeLengthMeters': holeLengthMeters,
      };

  factory WatchDistanceData.fromJson(Map<String, dynamic> json) =>
      WatchDistanceData(
        holeNumber: json['holeNumber'] as int,
        par: json['par'] as int,
        frontGreen:
            WatchDistance.fromJson(json['frontGreen'] as Map<String, dynamic>),
        centerGreen:
            WatchDistance.fromJson(json['centerGreen'] as Map<String, dynamic>),
        backGreen:
            WatchDistance.fromJson(json['backGreen'] as Map<String, dynamic>),
        pin: json['pin'] != null
            ? WatchDistance.fromJson(json['pin'] as Map<String, dynamic>)
            : null,
        hazards: (json['hazards'] as List<dynamic>?)
                ?.map(
                    (e) => WatchHazardDistance.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        confidence: (json['confidence'] as num).toDouble(),
        gpsAccuracyMeters: (json['gpsAccuracyMeters'] as num).toDouble(),
        isLive: json['isLive'] as bool? ?? true,
        computedAt: DateTime.parse(json['computedAt'] as String),
        holeLengthMeters: json['holeLengthMeters'] as int?,
      );

  @override
  List<Object?> get props => [
        holeNumber,
        par,
        frontGreen,
        centerGreen,
        backGreen,
        pin,
        hazards,
        confidence,
        gpsAccuracyMeters,
        isLive,
        computedAt,
        holeLengthMeters,
      ];
}
