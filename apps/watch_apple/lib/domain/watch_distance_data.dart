// Watch Distance Data — VSP Watch Apple App (Local Domain)
//
// Minimal distance data model for watch display.
// Mirrors packages/domain/lib/src/round/watch_distance_data.dart
// but is self-contained for the watch app.
//
// Story 10.1 — Slice 2: Watch UI Shell & Navigation

import 'package:equatable/equatable.dart';

/// A single distance value with confidence metadata.
class WatchDistance extends Equatable {
  final double meters;
  final double confidence;

  const WatchDistance({
    required this.meters,
    required this.confidence,
  });

  double get yards => meters * 1.09361;

  String format({required bool useYards}) =>
      useYards ? '${yards.round()} yd' : '${meters.round()} m';

  @override
  List<Object?> get props => [meters, confidence];
}

/// Hazard distance entry for watch display.
class WatchHazardDistance extends Equatable {
  final String type;
  final String label;
  final double meters;
  final double confidence;
  final double? carryMeters;

  const WatchHazardDistance({
    required this.type,
    required this.label,
    required this.meters,
    required this.confidence,
    this.carryMeters,
  });

  @override
  List<Object?> get props => [type, label, meters, confidence, carryMeters];
}

/// Watch distance data — displayed on the watch distance panel.
class WatchDistanceData extends Equatable {
  final int holeNumber;
  final int par;
  final WatchDistance frontGreen;
  final WatchDistance centerGreen;
  final WatchDistance backGreen;
  final WatchDistance? pin;
  final List<WatchHazardDistance> hazards;
  final double confidence;
  final double gpsAccuracyMeters;
  final bool isLive;
  final DateTime computedAt;
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

  List<WatchDistance> get fcb => [frontGreen, centerGreen, backGreen];

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

  bool get isAccurate => gpsAccuracyMeters <= 10;
  bool get hasAccuracyWarning => gpsAccuracyMeters >= 10;

  String get confidenceLabel {
    if (confidence >= 0.9) return 'High';
    if (confidence >= 0.7) return 'Medium';
    if (confidence >= 0.5) return 'Low';
    return 'Very Low';
  }

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
