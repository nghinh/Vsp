// Measure Leg & Result — VSP Mobile App
//
// The output of the manual measuring tool: a chain of legs from the golfer
// through each dropped point, optionally continuing to the green.
//
// Every distance carries an uncertainty. A measurement taken on a 30 m GPS fix
// is not a 142 m distance, it is "142 m, give or take 30" — and the golfer is
// told which one they have.

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/domain/value_objects/distance_measurement.dart';
import 'package:vsp_mobile/domain/value_objects/distance_type.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

/// What a leg connects.
enum MeasureLegKind {
  /// Golfer's GPS position → first dropped point.
  fromGolfer,

  /// One dropped point → the next dropped point.
  betweenPoints,

  /// Last dropped point → the green, when a green position is known.
  toGreen,
}

/// One straight-line segment of a measurement.
class MeasureLeg extends Equatable {
  /// What this leg connects.
  final MeasureLegKind kind;

  /// Start of the segment.
  final LatLng from;

  /// End of the segment.
  final LatLng to;

  /// Great-circle length in metres.
  final double meters;

  /// 1-sigma uncertainty of [meters] in metres.
  ///
  /// Combines the positional uncertainty of both endpoints in quadrature.
  final double uncertaintyMeters;

  const MeasureLeg({
    required this.kind,
    required this.from,
    required this.to,
    required this.meters,
    required this.uncertaintyMeters,
  });

  /// Confidence 0–1 derived from [uncertaintyMeters].
  double get confidence => MeasureQuality.confidenceFor(uncertaintyMeters);

  /// Quality bucket for honest display.
  MeasureQuality get quality =>
      MeasureQuality.forUncertainty(uncertaintyMeters);

  /// Adapts this leg to the shared [DistanceMeasurement] value object so the
  /// existing distance widgets can render it.
  ///
  /// Source is always [DistanceSource.estimated]: a point the golfer eyeballed
  /// on aerial imagery is never official course data.
  DistanceMeasurement toMeasurement({DateTime? timestamp}) {
    return DistanceMeasurement(
      valueMeters: meters,
      type: kind == MeasureLegKind.toGreen
          ? DistanceType.targetToPin
          : DistanceType.target,
      source: DistanceSource.estimated,
      timestamp: timestamp,
      gpsAccuracyMeters: uncertaintyMeters,
      confidence: confidence,
    );
  }

  @override
  List<Object?> get props => [kind, from, to, meters, uncertaintyMeters];
}

/// How much a measurement can be trusted.
enum MeasureQuality {
  /// Uncertainty under 3 m — as good as a laser on a calm day.
  good,

  /// Uncertainty 3–8 m — usable for club selection.
  fair,

  /// Uncertainty 8–20 m — rough guidance only.
  poor,

  /// Uncertainty over 20 m, or no fix at all — do not trust the number.
  unusable;

  /// Bucket for a 1-sigma uncertainty in metres.
  static MeasureQuality forUncertainty(double uncertaintyMeters) {
    if (uncertaintyMeters.isNaN) return MeasureQuality.unusable;
    if (uncertaintyMeters < 3) return MeasureQuality.good;
    if (uncertaintyMeters < 8) return MeasureQuality.fair;
    if (uncertaintyMeters <= 20) return MeasureQuality.poor;
    return MeasureQuality.unusable;
  }

  /// Confidence 0–1 for a 1-sigma uncertainty in metres.
  ///
  /// Monotonically decreasing; mapped onto the same 0–1 scale the rest of the
  /// app uses so [DistanceMeasurement.confidenceLevel] stays meaningful.
  static double confidenceFor(double uncertaintyMeters) {
    if (uncertaintyMeters.isNaN || uncertaintyMeters < 0) return 0.0;
    if (uncertaintyMeters < 3) return 0.95;
    if (uncertaintyMeters < 8) return 0.8;
    if (uncertaintyMeters <= 20) return 0.6;
    return 0.3;
  }
}

/// A complete measurement: every leg, plus the totals a golfer actually reads.
class MeasureResult extends Equatable {
  /// Legs from the golfer through each dropped point, in order.
  ///
  /// Empty when there are no points, or when there is no GPS fix and fewer
  /// than two points.
  final List<MeasureLeg> legs;

  /// Leg from the last dropped point to the green, when a green is known.
  final MeasureLeg? greenLeg;

  /// True when a GPS fix anchored the first leg.
  final bool hasGolferOrigin;

  /// GPS accuracy in metres at the time of measuring, when known.
  final double? gpsAccuracyMeters;

  /// True when the GPS fix was stale.
  final bool gpsStale;

  /// True when a green position exists but is estimated rather than surveyed.
  final bool greenIsEstimated;

  const MeasureResult({
    this.legs = const [],
    this.greenLeg,
    this.hasGolferOrigin = false,
    this.gpsAccuracyMeters,
    this.gpsStale = false,
    this.greenIsEstimated = false,
  });

  /// The empty measurement.
  static const MeasureResult empty = MeasureResult();

  /// True when there is nothing to show.
  bool get isEmpty => legs.isEmpty && greenLeg == null;

  /// Distance from the golfer to the first dropped point, when both exist.
  MeasureLeg? get firstLeg {
    for (final leg in legs) {
      if (leg.kind == MeasureLegKind.fromGolfer) return leg;
    }
    return null;
  }

  /// Walked total along every leg in metres (excludes [greenLeg]).
  double get totalMeters =>
      legs.fold<double>(0, (sum, leg) => sum + leg.meters);

  /// Total including the leg on to the green, when there is one.
  double get totalWithGreenMeters => totalMeters + (greenLeg?.meters ?? 0);

  /// 1-sigma uncertainty of [totalMeters].
  ///
  /// Legs share endpoints, so their errors are partly correlated and partly
  /// cancel. Adding the variances treats them as independent, which
  /// over-states the spread — deliberately, because over-stating uncertainty
  /// is the safe direction to be wrong in.
  double get totalUncertaintyMeters {
    if (legs.isEmpty) return 0;
    var variance = 0.0;
    for (final leg in legs) {
      variance += leg.uncertaintyMeters * leg.uncertaintyMeters;
    }
    return math.sqrt(variance);
  }

  /// Worst quality across all legs — the measurement is only as good as its
  /// weakest link.
  MeasureQuality get quality {
    if (isEmpty) return MeasureQuality.unusable;
    var worst = MeasureQuality.good;
    for (final leg in [...legs, if (greenLeg != null) greenLeg!]) {
      if (leg.quality.index > worst.index) worst = leg.quality;
    }
    return worst;
  }

  /// True when the numbers should be presented with an explicit warning.
  bool get needsWarning =>
      gpsStale ||
      quality == MeasureQuality.poor ||
      quality == MeasureQuality.unusable;

  @override
  List<Object?> get props => [
    legs,
    greenLeg,
    hasGolferOrigin,
    gpsAccuracyMeters,
    gpsStale,
    greenIsEstimated,
  ];
}
