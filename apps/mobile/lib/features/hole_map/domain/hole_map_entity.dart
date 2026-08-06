// HoleMapEntity — VSP Mobile App
//
// Domain aggregate root for the hole map feature.
// Holds all map layers, markers, and overlay data for a single hole.

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';

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
  double? get mapCenterLat {
    if (pin != null) return pin!.latitude;
    if (golferPosition != null) return golferPosition!.latitude;
    return null;
  }

  double? get mapCenterLng {
    if (pin != null) return pin!.longitude;
    if (golferPosition != null) return golferPosition!.longitude;
    return null;
  }

  /// Zoom level appropriate for the hole scope.
  double get defaultZoom => 16.0;

  HoleMapEntity copyWith({
    String? courseId,
    String? courseName,
    int? holeNumber,
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
