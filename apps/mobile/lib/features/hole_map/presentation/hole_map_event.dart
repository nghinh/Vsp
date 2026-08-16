// HoleMapEvent — VSP Mobile App
//
// BLoC events for the hole map feature.

import 'package:equatable/equatable.dart';

/// Base class for all hole map events.
abstract class HoleMapEvent extends Equatable {
  const HoleMapEvent();

  @override
  List<Object?> get props => [];
}

/// Load the hole map for a specific course and hole.
class LoadHoleMap extends HoleMapEvent {
  /// Downloaded course package holding this hole's geometry.
  ///
  /// Null when the course has no package on this device — the common case, and
  /// not an error. The bloc answers with [HoleMapUnsurveyed] rather than asking
  /// a repository for geometry that provably is not there.
  final String? packageId;
  final String courseId;
  final String courseName;
  final int holeNumber;

  const LoadHoleMap({
    this.packageId,
    required this.courseId,
    required this.courseName,
    required this.holeNumber,
  });

  @override
  List<Object?> get props => [packageId, courseId, courseName, holeNumber];
}

/// Update the golfer's current GPS position on the map.
class UpdateGolferPosition extends HoleMapEvent {
  final double latitude;
  final double longitude;
  final double? accuracy;

  const UpdateGolferPosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  @override
  List<Object?> get props => [latitude, longitude, accuracy];
}

/// Place or move the target marker on the map.
class UpdateTarget extends HoleMapEvent {
  final double latitude;
  final double longitude;
  final String? label;

  const UpdateTarget({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  @override
  List<Object?> get props => [latitude, longitude, label];
}

/// Remove the target marker from the map.
class ClearTarget extends HoleMapEvent {
  const ClearTarget();
}

/// Toggle visibility of a specific map layer.
class ToggleLayerVisibility extends HoleMapEvent {
  final String layerId;
  final bool visible;

  const ToggleLayerVisibility({required this.layerId, required this.visible});

  @override
  List<Object?> get props => [layerId, visible];
}

/// Navigate to a different hole.
class NavigateToHole extends HoleMapEvent {
  final int holeNumber;

  /// The đường that holds the hole, where the round crosses from one to
  /// another. Null keeps the map on the course it is already showing.
  ///
  /// A round of two nines changes course at hole 10, and the hole number
  /// alone cannot say so: hole 10 of the round is hole 1 of the back nine,
  /// and navigating to "hole 1" without this left the map on the front nine's
  /// first — the right number, the wrong hole, and no way for a golfer to
  /// tell from the screen.
  final String? courseId;

  const NavigateToHole({required this.holeNumber, this.courseId});

  @override
  List<Object?> get props => [holeNumber, courseId];
}

/// Retry loading after an error.
class RetryLoadHoleMap extends HoleMapEvent {
  const RetryLoadHoleMap();
}
