// Measure Calculator — VSP Mobile App
//
// Turns "golfer position + a handful of tapped points + maybe a green" into
// distances a golfer can act on, each with an honest error bar.
//
// Pure domain logic — no Flutter, no plugins, fully unit-testable.

import 'dart:math' as math;

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

import 'measure_leg.dart';
import 'measure_point.dart';

/// Calculates measuring-tool distances and their uncertainties.
class MeasureCalculator {
  /// Positional uncertainty of a point tapped on satellite imagery, in metres.
  ///
  /// Two things go wrong when a golfer taps a pond edge on an aerial photo:
  /// the imagery itself is georeferenced imperfectly (a few metres for
  /// commercial satellite basemaps), and the finger is wider than the feature.
  /// 5 m is a deliberately unglamorous estimate for both together — it keeps
  /// us from advertising sub-metre precision we do not have.
  static const double defaultTapUncertaintyMeters = 5.0;

  /// Uncertainty assumed when the GPS fix reports no accuracy at all.
  ///
  /// A fix that will not say how good it is gets treated as bad.
  static const double unknownGpsUncertaintyMeters = 50.0;

  /// Uncertainty of a green position that was surveyed.
  static const double surveyedGreenUncertaintyMeters = 2.0;

  /// Uncertainty of a green position that was derived or estimated.
  ///
  /// 830 of our 900 holes are in this bucket; pretending otherwise would be
  /// the whole problem this feature exists to avoid.
  static const double estimatedGreenUncertaintyMeters = 25.0;

  /// Per-point tap uncertainty used by this instance.
  final double tapUncertaintyMeters;

  const MeasureCalculator({
    this.tapUncertaintyMeters = defaultTapUncertaintyMeters,
  });

  /// Computes every leg of a measurement.
  ///
  /// [points] are the golfer's dropped points in tap order. [origin] is the
  /// current GPS fix, or null when there is no usable fix — in that case the
  /// chain simply starts at the first dropped point and the panel says the
  /// golfer's own position is unknown. [green] is the green/pin position when
  /// the course package has one.
  MeasureResult compute({
    required List<MeasurePoint> points,
    QualifiedLocation? origin,
    MeasureAnchor? green,
  }) {
    final usableOrigin = _usableOrigin(origin);
    final originUncertainty = usableOrigin == null
        ? null
        : (usableOrigin.accuracyMeters ?? unknownGpsUncertaintyMeters);

    final legs = <MeasureLeg>[];

    if (usableOrigin != null && points.isNotEmpty) {
      final originPosition = LatLng(
        latitude: usableOrigin.latitude,
        longitude: usableOrigin.longitude,
      );
      legs.add(
        _leg(
          kind: MeasureLegKind.fromGolfer,
          from: originPosition,
          to: points.first.position,
          fromUncertainty: originUncertainty!,
          toUncertainty: tapUncertaintyMeters,
        ),
      );
    }

    for (var i = 0; i + 1 < points.length; i++) {
      legs.add(
        _leg(
          kind: MeasureLegKind.betweenPoints,
          from: points[i].position,
          to: points[i + 1].position,
          fromUncertainty: tapUncertaintyMeters,
          toUncertainty: tapUncertaintyMeters,
        ),
      );
    }

    MeasureLeg? greenLeg;
    if (green != null && points.isNotEmpty) {
      greenLeg = _leg(
        kind: MeasureLegKind.toGreen,
        from: points.last.position,
        to: green.position,
        fromUncertainty: tapUncertaintyMeters,
        toUncertainty: green.isSurveyed
            ? surveyedGreenUncertaintyMeters
            : estimatedGreenUncertaintyMeters,
      );
    }

    return MeasureResult(
      legs: List.unmodifiable(legs),
      greenLeg: greenLeg,
      hasGolferOrigin: usableOrigin != null,
      gpsAccuracyMeters: usableOrigin?.accuracyMeters,
      gpsStale: origin?.isStale ?? false,
      greenIsEstimated: green != null && !green.isSurveyed,
    );
  }

  /// Distance in metres between two coordinates (haversine).
  ///
  /// Delegates to the shared [LatLng.distanceTo] so the whole app measures
  /// the earth the same way.
  static double distanceMeters(LatLng a, LatLng b) => a.distanceTo(b);

  /// Combines two independent 1-sigma positional errors in quadrature.
  static double combineUncertainty(double a, double b) =>
      math.sqrt(a * a + b * b);

  MeasureLeg _leg({
    required MeasureLegKind kind,
    required LatLng from,
    required LatLng to,
    required double fromUncertainty,
    required double toUncertainty,
  }) {
    return MeasureLeg(
      kind: kind,
      from: from,
      to: to,
      meters: distanceMeters(from, to),
      uncertaintyMeters: combineUncertainty(fromUncertainty, toUncertainty),
    );
  }

  /// A fix with no source is not a position — treat it as absent.
  QualifiedLocation? _usableOrigin(QualifiedLocation? origin) {
    if (origin == null) return null;
    if (origin.source == LocationSource.unavailable) return null;
    return origin;
  }
}

/// Finds which dropped point (if any) a tap landed on, so tapping a marker
/// removes it instead of dropping another point on top of it.
abstract final class MeasureHitTester {
  /// Touch target radius in logical pixels — matches the 44pt minimum used
  /// elsewhere in the app, halved to a radius.
  static const double touchRadiusPixels = 22.0;

  /// Ground resolution in metres per logical pixel for a web-mercator tile
  /// pyramid at [zoom] and [latitude].
  static double metersPerPixel({
    required double zoom,
    required double latitude,
  }) {
    const equatorCircumference = 40075016.686;
    final latRad = latitude * math.pi / 180.0;
    return equatorCircumference *
        math.cos(latRad).abs() /
        (256.0 * math.pow(2, zoom));
  }

  /// Radius in metres that corresponds to a comfortable touch target.
  static double touchRadiusMeters({
    required double zoom,
    required double latitude,
  }) {
    return metersPerPixel(zoom: zoom, latitude: latitude) * touchRadiusPixels;
  }

  /// Returns the closest point within [thresholdMeters] of [tap], or null.
  static MeasurePoint? findNearest({
    required List<MeasurePoint> points,
    required LatLng tap,
    required double thresholdMeters,
  }) {
    MeasurePoint? best;
    var bestDistance = double.infinity;
    for (final point in points) {
      final distance = point.position.distanceTo(tap);
      if (distance <= thresholdMeters && distance < bestDistance) {
        best = point;
        bestDistance = distance;
      }
    }
    return best;
  }
}
