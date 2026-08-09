// Measure Point — VSP Mobile App
//
// A point the golfer dropped on the satellite basemap: a pond edge, a bunker
// lip, a layup target, the flag they can see but we have no coordinate for.

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

/// A single golfer-placed measuring point.
class MeasurePoint extends Equatable {
  /// Stable identifier so a marker can be tapped again to remove it.
  final String id;

  /// WGS84 position the golfer tapped.
  final LatLng position;

  const MeasurePoint({required this.id, required this.position});

  double get latitude => position.latitude;
  double get longitude => position.longitude;

  /// Same point, somewhere else. Keeps [id], which is what keeps the point in
  /// its place in the measured chain when a golfer drags it.
  MeasurePoint copyWith({LatLng? position}) =>
      MeasurePoint(id: id, position: position ?? this.position);

  @override
  List<Object?> get props => [id, position];
}

/// Where the green is, when we know.
///
/// [isSurveyed] is false for derived/estimated positions. The UI must say so —
/// most of our holes have no surveyed green and a golfer deserves to know
/// whether "142 m to the green" rests on a survey or on an estimate.
class MeasureAnchor extends Equatable {
  /// Position of the green (pin or green centre).
  final LatLng position;

  /// True only when this position came from surveyed/official course data.
  final bool isSurveyed;

  const MeasureAnchor({required this.position, required this.isSurveyed});

  @override
  List<Object?> get props => [position, isSurveyed];
}
