// HoleMapEntity — VSP Mobile App
//
// Domain aggregate root for the hole map feature.
// Holds all map layers, markers, and overlay data for a single hole.

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

import 'hole_geometry_coverage.dart';
import 'map_layer.dart';
import 'pin_entity.dart';
import 'target_entity.dart';
import 'wind_entity.dart';
import 'golfer_position_entity.dart';
import 'distance_ring_entity.dart';

/// Aggregate root for a single hole's strategic map.
class HoleMapEntity extends Equatable {
  final String courseId;
  final String courseName;
  final int holeNumber;

  /// The hole's identifier in the course database, as the package recorded it.
  ///
  /// Distinct from [holeNumber], and the distinction matters: hole 1 of Long
  /// Thành is row 127, while row 1 is hole 1 of a course in Hà Nội. Anything
  /// reported back to the server has to carry this, not the number a golfer
  /// reads on the tee marker. Null when the package predates the field.
  final String? holeId;
  final int par;
  final int? yardage;
  final Map<MapLayerType, MapLayerEntity> layers;
  final PinEntity? pin;
  final GolferPositionEntity? golferPosition;
  final TargetEntity? target;
  final WindEntity? wind;
  final List<DistanceRingEntity> distanceRings;

  /// Where this hole's coordinates came from.
  ///
  /// Defaults to [HoleDataProvenance.unknown], which is not surveyed. Every
  /// number on this map — the header yardage, the rings, the distance to the
  /// green — is computed from those coordinates, so a hole that arrives
  /// without provenance must be drawn as unverified rather than trusted.
  final HoleDataProvenance provenance;

  const HoleMapEntity({
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
    this.holeId,
    required this.par,
    this.yardage,
    this.layers = const {},
    this.pin,
    this.golferPosition,
    this.target,
    this.wind,
    this.distanceRings = const [],
    this.provenance = HoleDataProvenance.unknown,
  });

  /// True when a human verified coordinates obtained by survey, licence or
  /// satellite digitisation.
  bool get isSurveyed => provenance.isSurveyed;

  /// Center point for the map camera (midpoint of fairway or pin location).
  /// Where the strategic map should point.
  ///
  /// The hole's own geometry first. It used to be the pin, then the golfer —
  /// and a course package carries no pin positions, so in practice it was
  /// always the golfer. That framed the hole correctly only while standing on
  /// it: opening the map from the clubhouse, or stepping to the next hole to
  /// look at it, pointed the camera at the golfer and left the hole outside
  /// the frame. The map looked broken because it was aimed at the wrong place.
  ///
  /// Pin and golfer remain as fallbacks for a hole with no geometry, which is
  /// where the satellite path takes over anyway.
  double? get mapCenterLat => _mapCenter?.latitude ?? _fallbackCenterLat;

  double? get mapCenterLng => _mapCenter?.longitude ?? _fallbackCenterLng;

  LatLng? get _mapCenter => HoleGeometryCoverage.holeCenter(this);

  double? get _fallbackCenterLat {
    if (pin != null) return pin!.latitude;
    if (golferPosition != null) return golferPosition!.latitude;
    return null;
  }

  double? get _fallbackCenterLng {
    if (pin != null) return pin!.longitude;
    if (golferPosition != null) return golferPosition!.longitude;
    return null;
  }

  /// The two ends of the hole, where the package carries them.
  ///
  /// Most holes in this database have exactly these two points and no
  /// polygons at all — the map was drawing them as two dots and saying
  /// nothing about the golf between them.
  LatLng? get teeCenter =>
      HoleGeometryCoverage.layerCenter(this, MapLayerType.tee);

  LatLng? get greenCenter =>
      HoleGeometryCoverage.layerCenter(this, MapLayerType.green);

  /// What the golfer is aiming at: the flag where the club published one,
  /// the middle of the green otherwise.
  LatLng? get aimPoint {
    final flag = pin;
    if (flag != null && !flag.isExpired) {
      return LatLng(latitude: flag.latitude, longitude: flag.longitude);
    }
    return greenCenter;
  }

  /// Zoom level appropriate for the hole scope.
  double get defaultZoom => 16.0;

  HoleMapEntity copyWith({
    String? courseId,
    String? courseName,
    int? holeNumber,
    String? holeId,
    int? par,
    int? yardage,
    Map<MapLayerType, MapLayerEntity>? layers,
    PinEntity? pin,
    GolferPositionEntity? golferPosition,
    TargetEntity? target,
    WindEntity? wind,
    List<DistanceRingEntity>? distanceRings,
    HoleDataProvenance? provenance,
  }) {
    return HoleMapEntity(
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      holeNumber: holeNumber ?? this.holeNumber,
      holeId: holeId ?? this.holeId,
      par: par ?? this.par,
      yardage: yardage ?? this.yardage,
      layers: layers ?? this.layers,
      pin: pin ?? this.pin,
      golferPosition: golferPosition ?? this.golferPosition,
      target: target ?? this.target,
      wind: wind ?? this.wind,
      distanceRings: distanceRings ?? this.distanceRings,
      provenance: provenance ?? this.provenance,
    );
  }

  @override
  List<Object?> get props => [
    courseId,
    courseName,
    holeNumber,
    holeId,
    par,
    yardage,
    layers,
    pin,
    golferPosition,
    target,
    wind,
    distanceRings,
    provenance,
  ];
}
