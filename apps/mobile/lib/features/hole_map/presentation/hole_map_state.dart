// HoleMapState — VSP Mobile App
//
// BLoC states for the hole map feature.

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
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

  /// True while shapes on this hole were traced from satellite imagery and
  /// nobody has checked them against the ground. The screen says so — a
  /// bunker drawn by a model looks exactly like a surveyed one, and a golfer
  /// laying up to it deserves to know which they are looking at.
  final bool tracedShapesUnverified;

  const HoleMapReady({
    this.tracedShapesUnverified = false,
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
    bool? tracedShapesUnverified,
  }) {
    return HoleMapReady(
      holeMap: holeMap ?? this.holeMap,
      golferPosition: golferPosition ?? this.golferPosition,
      target: target ?? this.target,
      wind: wind ?? this.wind,
      windRelative: windRelative ?? this.windRelative,
      distanceRings: distanceRings ?? this.distanceRings,
      layerVisibility: layerVisibility ?? this.layerVisibility,
      tracedShapesUnverified:
          tracedShapesUnverified ?? this.tracedShapesUnverified,
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
    tracedShapesUnverified,
  ];
}

/// The hole has no geometry we could draw — and that is an answer, not a fault.
///
/// Two situations reach here and they are the same situation for the golfer:
/// the course has no downloaded package at all (~all of the courses in the
/// app), or a package exists but carries nothing for this hole. Either way
/// there is no surveyed shape to render, so the map falls back to satellite
/// imagery and the measuring tool — the imagery is real even where our vector
/// data is not. The two are not distinguished because nothing the golfer can
/// do about one differs from the other.
class HoleMapUnsurveyed extends HoleMapState {
  final String courseName;
  final int holeNumber;

  /// Where the club is, so the photograph opens over golf.
  ///
  /// Reported from the course with a screenshot of the 12th: the header read
  /// "Long Biên Golf Course" and the picture underneath was a street of
  /// rooftops — "Sao vẫn không hiện vị trí sân". Nothing was wrong with the
  /// imagery. This state carried a name and a number and no position at all,
  /// so the measuring view had nowhere to aim and did the only thing left,
  /// which is to centre on the golfer. The golfer was at home.
  ///
  /// A hole nobody has traced still belongs to a club with a published
  /// latitude and longitude, and that is what a golfer opening the map is
  /// asking to see. Null only where the club's own position is unknown or
  /// unreachable, which is the case that still falls back to the golfer.
  final LatLng? courseLocation;

  const HoleMapUnsurveyed({
    required this.courseName,
    required this.holeNumber,
    this.courseLocation,
  });

  @override
  List<Object?> get props => [courseName, holeNumber, courseLocation];
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
