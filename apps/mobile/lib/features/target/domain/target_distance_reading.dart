// Target Distance Reading — VSP Mobile App
//
// What the golfer actually wants to know once they have dropped a target on
// the hole map: how far it is from where they are standing, and how much is
// left from there to the green.
//
// Both numbers are computed by [MeasureCalculator] — the same geodesy and the
// same uncertainty model the measuring tool uses — so a distance never changes
// depending on which screen renders it, and neither number is ever quoted
// without the error bar it earned. Where an input is missing (no GPS fix, no
// known green, no target) the corresponding leg is simply absent: an invented
// position would produce a confident number that is wrong, which is worse for
// club selection than no number at all.
//
// Pure domain logic — no Flutter, no plugins.

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/target_entity.dart';
import 'package:vsp_mobile/features/measure/domain/measure_calculator.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';

/// The distances around a placed target, each with its uncertainty.
class TargetDistanceReading {
  /// Golfer → target. Null when there is no target or no usable GPS fix.
  final MeasureLeg? fromGolfer;

  /// Target → green. Null when there is no target or no known green.
  final MeasureLeg? onToGreen;

  /// The target the reading was taken for, when one is placed.
  final TargetEntity? target;

  /// The GPS fix the reading rests on, when there is a usable one.
  final QualifiedLocation? fix;

  /// True when a green position exists but was derived rather than surveyed.
  final bool greenIsEstimated;

  /// True when this hole has no green position at all.
  final bool greenUnknown;

  const TargetDistanceReading({
    this.fromGolfer,
    this.onToGreen,
    this.target,
    this.fix,
    this.greenIsEstimated = false,
    this.greenUnknown = true,
  });

  /// True when the golfer has placed a target.
  bool get hasTarget => target != null;

  /// True when there is a usable fix to measure from.
  bool get hasGolferFix => fromGolfer != null;

  /// Identifier used for the synthetic measuring point standing in for the
  /// target. Stable so recomputation never churns.
  static const String targetPointId = 'target';

  /// Reads the distances for [target] from [golfer], continuing to [green].
  ///
  /// [golfer] may be null or unavailable, [green] may be null, and [target] may
  /// be null; each absence removes exactly the leg that depended on it and
  /// nothing else.
  static TargetDistanceReading of({
    TargetEntity? target,
    QualifiedLocation? golfer,
    MeasureAnchor? green,
    MeasureCalculator calculator = const MeasureCalculator(),
  }) {
    if (target == null) {
      return TargetDistanceReading(
        fix: _usable(golfer),
        greenIsEstimated: green != null && !green.isSurveyed,
        greenUnknown: green == null,
      );
    }

    final result = calculator.compute(
      points: [
        MeasurePoint(
          id: targetPointId,
          position: LatLng(
            latitude: target.latitude,
            longitude: target.longitude,
          ),
        ),
      ],
      origin: golfer,
      green: green,
    );

    return TargetDistanceReading(
      fromGolfer: result.firstLeg,
      onToGreen: result.greenLeg,
      target: target,
      fix: _usable(golfer),
      greenIsEstimated: result.greenIsEstimated,
      greenUnknown: green == null,
    );
  }

  static QualifiedLocation? _usable(QualifiedLocation? fix) {
    if (fix == null || fix.source == LocationSource.unavailable) return null;
    return fix;
  }
}
