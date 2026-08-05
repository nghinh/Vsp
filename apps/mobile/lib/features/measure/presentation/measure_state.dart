// Measure State — VSP Mobile App
//
// State for the manual measuring tool.

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Current state of the measuring tool.
class MeasureState extends Equatable {
  /// Points the golfer dropped, in tap order.
  final List<MeasurePoint> points;

  /// Latest GPS fix, or null before the first fix arrives.
  final QualifiedLocation? origin;

  /// Green/pin position for this hole, when the course package has one.
  final MeasureAnchor? green;

  /// Golfer's display unit preference.
  final DistanceUnit unit;

  /// Computed legs and totals for [points].
  final MeasureResult result;

  const MeasureState({
    this.points = const [],
    this.origin,
    this.green,
    this.unit = DistanceUnit.meters,
    this.result = MeasureResult.empty,
  });

  /// True when the golfer has not dropped anything yet.
  bool get isEmpty => points.isEmpty;

  /// True when we have no usable GPS fix, so distances "from you" cannot be
  /// shown at all.
  bool get hasNoFix =>
      origin == null || origin!.source == LocationSource.unavailable;

  /// True when the fix exists but is not good enough to be quoted without a
  /// warning.
  bool get fixIsWeak => !hasNoFix && origin!.hasWarning;

  MeasureState copyWith({
    List<MeasurePoint>? points,
    QualifiedLocation? origin,
    MeasureAnchor? green,
    DistanceUnit? unit,
    MeasureResult? result,
    bool clearOrigin = false,
  }) {
    return MeasureState(
      points: points ?? this.points,
      origin: clearOrigin ? null : (origin ?? this.origin),
      green: green ?? this.green,
      unit: unit ?? this.unit,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [points, origin, green, unit, result];
}
