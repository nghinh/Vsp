// HoleMapState — VSP Mobile App
//
// BLoC states for the hole map feature.

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/golfer_position_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/target_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/wind_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/wind_relative_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/distance_ring_entity.dart';

/// Base class for all hole map states.
abstract class HoleMapState extends Equatable {
  const HoleMapState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any map is loaded.
class HoleMapInitial extends HoleMapState {
  const HoleMapInitial();
}

/// Map is loading (fetching geometry from local package).
class HoleMapLoading extends HoleMapState {
  final String? courseName;
  final int? holeNumber;

  const HoleMapLoading({this.courseName, this.holeNumber});

  @override
  List<Object?> get props => [courseName, holeNumber];
}

/// Map is ready with full hole data loaded.
class HoleMapReady extends HoleMapState {
  final HoleMapEntity holeMap;
  final GolferPositionEntity? golferPosition;
  final TargetEntity? target;
  final WindEntity? wind;
  final WindRelativeEntity? windRelative;
  final List<DistanceRingEntity> distanceRings;
  final Map<String, bool> layerVisibility;

  const HoleMapReady({
    required this.holeMap,
    this.golferPosition,
    this.target,
    this.wind,
    this.windRelative,
    this.distanceRings = const [],
    this.layerVisibility = const {},
  });

  HoleMapReady copyWith({
    HoleMapEntity? holeMap,
    GolferPositionEntity? golferPosition,
    TargetEntity? target,
    WindEntity? wind,
    WindRelativeEntity? windRelative,
    List<DistanceRingEntity>? distanceRings,
    Map<String, bool>? layerVisibility,
  }) {
    return HoleMapReady(
      holeMap: holeMap ?? this.holeMap,
      golferPosition: golferPosition ?? this.golferPosition,
      target: target ?? this.target,
      wind: wind ?? this.wind,
      windRelative: windRelative ?? this.windRelative,
      distanceRings: distanceRings ?? this.distanceRings,
      layerVisibility: layerVisibility ?? this.layerVisibility,
    );
  }

  @override
  List<Object?> get props => [
    holeMap,
    golferPosition,
    target,
    wind,
    windRelative,
    distanceRings,
    layerVisibility,
  ];
}

/// An error occurred while loading or rendering the map.
class HoleMapError extends HoleMapState {
  final String message;
  final String? courseName;
  final int? holeNumber;

  const HoleMapError({required this.message, this.courseName, this.holeNumber});

  @override
  List<Object?> get props => [message, courseName, holeNumber];
}
