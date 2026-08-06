// Green Distance Reading — VSP Mobile App
//
// Front, centre and back of the green from where the golfer is standing.
//
// These are the three numbers a golfer looks at before every approach shot,
// and until now the app could not produce them. There was a screen that
// promised them — `active_round_distances_screen.dart`, wired to a
// `DistanceCubit` and a parallel `HoleGeometry` model — but nothing in the app
// ever built that model from a downloaded course package, so it would have
// answered "No hole data" on every hole in production. The capability was
// worth keeping; the plumbing was not. This computes the same three distances
// from the green polygon the hole map already loads.
//
// A green is a shape, not a point: the near edge, the middle and the far edge
// are commonly a club and a half apart. Front is the nearest vertex of the
// polygon, back the farthest, centre the mean of them all — measured from the
// golfer's own position, so all three move as they walk.
//
// Every leg comes from [MeasureCalculator], the same geodesy and the same
// uncertainty model the measuring tool and the target readout use, so no two
// screens ever quote the same distance differently. The polygon's own error
// bar is the one the calculator already gives a point picked off aerial
// imagery — which is what a digitised green outline is.
//
// Pure domain logic — no Flutter, no plugins.

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'hole_geometry_coverage.dart';
import 'hole_map_entity.dart';
import 'package:vsp_mobile/features/measure/domain/measure_calculator.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';

/// Front / centre / back distances to the green, each with its uncertainty.
class GreenDistanceReading {
  /// Golfer → nearest point of the green.
  final MeasureLeg? front;

  /// Golfer → mean of the green outline.
  final MeasureLeg? centre;

  /// Golfer → farthest point of the green.
  final MeasureLeg? back;

  const GreenDistanceReading({this.front, this.centre, this.back});

  /// Nothing to show: no fix, no green, or a green with no depth to it.
  static const GreenDistanceReading none = GreenDistanceReading();

  /// True when all three distances are available.
  bool get hasDistances => front != null && centre != null && back != null;

  /// Minimum front-to-back spread, in metres, for a green to be worth
  /// splitting into three numbers.
  ///
  /// Below this the polygon is a marker rather than an outline, and three
  /// identical figures dressed up as front, centre and back would suggest a
  /// precision the geometry does not have.
  static const double minimumDepthMeters = 5.0;

  /// Reads the three distances for [holeMap] from [golfer].
  ///
  /// Returns [none] when there is no usable fix, when the hole carries no
  /// green geometry, or when what geometry it carries has no depth: each
  /// absence removes the whole reading, because front, centre and back are
  /// only meaningful together.
  static GreenDistanceReading of({
    required HoleMapEntity holeMap,
    QualifiedLocation? golfer,
    MeasureCalculator calculator = const MeasureCalculator(),
  }) {
    if (golfer == null || golfer.source == LocationSource.unavailable) {
      return none;
    }

    final outline = HoleGeometryCoverage.greenOutline(holeMap);
    if (outline.length < 3) return none;

    final origin = LatLng(
      latitude: golfer.latitude,
      longitude: golfer.longitude,
    );

    var nearest = outline.first;
    var farthest = outline.first;
    var nearestMeters = double.infinity;
    var farthestMeters = -1.0;
    var latSum = 0.0;
    var lngSum = 0.0;

    for (final point in outline) {
      final meters = MeasureCalculator.distanceMeters(origin, point);
      if (meters < nearestMeters) {
        nearestMeters = meters;
        nearest = point;
      }
      if (meters > farthestMeters) {
        farthestMeters = meters;
        farthest = point;
      }
      latSum += point.latitude;
      lngSum += point.longitude;
    }

    if (farthestMeters - nearestMeters < minimumDepthMeters) return none;

    final centre = LatLng(
      latitude: latSum / outline.length,
      longitude: lngSum / outline.length,
    );

    return GreenDistanceReading(
      front: _leg(calculator, golfer, 'green-front', nearest),
      centre: _leg(calculator, golfer, 'green-centre', centre),
      back: _leg(calculator, golfer, 'green-back', farthest),
    );
  }

  static MeasureLeg? _leg(
    MeasureCalculator calculator,
    QualifiedLocation golfer,
    String id,
    LatLng position,
  ) {
    return calculator
        .compute(
          points: [MeasurePoint(id: id, position: position)],
          origin: golfer,
        )
        .firstLeg;
  }
}
