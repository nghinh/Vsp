// Target State — VSP Mobile App
//
// State classes for target placement and distance display.
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'package:equatable/equatable.dart';

import '../domain/target_model.dart';

/// Drag lifecycle state for target annotation.
enum TargetDragMode {
  /// No drag in progress; map gestures are active.
  none,

  /// Long-press detected; drag starting; map gestures being suppressed.
  /// While in this state, map pan/zoom is disabled.
  dragging,
}

/// Distance unit preference.
enum DistanceUnit { meters, yards }

/// Computed distances from ball → target and target → pin.
class TargetDistances extends Equatable {
  final double ballToTargetMeters;
  final double targetToPinMeters;
  final DistanceUnit unit;
  final GpsAccuracy accuracy;
  final DateTime timestamp;

  const TargetDistances({
    required this.ballToTargetMeters,
    required this.targetToPinMeters,
    required this.unit,
    required this.accuracy,
    required this.timestamp,
  });

  double ballToTarget(DistanceUnit u) => u == DistanceUnit.meters
      ? ballToTargetMeters
      : ballToTargetMeters * 1.09361;

  double targetToPin(DistanceUnit u) => u == DistanceUnit.meters
      ? targetToPinMeters
      : targetToPinMeters * 1.09361;

  @override
  List<Object?> get props => [
    ballToTargetMeters,
    targetToPinMeters,
    unit,
    accuracy,
    timestamp,
  ];
}

/// State for target placement on a hole.
class TargetState extends Equatable {
  /// The currently placed target, or null if none.
  final TargetModel? target;

  /// Computed distances (ball → target, target → pin).
  final TargetDistances? distances;

  /// Whether distances are being computed.
  final bool isLoading;

  /// Error message if placement or distance calc failed.
  final String? errorMessage;

  /// Drag mode state (Slice 2).
  final TargetDragMode dragMode;

  const TargetState({
    this.target,
    this.distances,
    this.isLoading = false,
    this.errorMessage,
    this.dragMode = TargetDragMode.none,
  });

  /// True if a target is currently placed.
  bool get hasTarget => target != null;

  /// True if distances are available.
  bool get hasDistances => distances != null;

  /// True if a drag operation is in progress.
  bool get isDragging => dragMode == TargetDragMode.dragging;

  const TargetState.initial()
    : target = null,
      distances = null,
      isLoading = false,
      errorMessage = null,
      dragMode = TargetDragMode.none;

  TargetState copyWith({
    TargetModel? target,
    TargetDistances? distances,
    bool? isLoading,
    String? errorMessage,
    TargetDragMode? dragMode,
    bool clearTarget = false,
    bool clearDistances = false,
    bool clearError = false,
  }) {
    return TargetState(
      target: clearTarget ? null : (target ?? this.target),
      distances: clearDistances ? null : (distances ?? this.distances),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      dragMode: dragMode ?? this.dragMode,
    );
  }

  @override
  List<Object?> get props => [
    target,
    distances,
    isLoading,
    errorMessage,
    dragMode,
  ];
}
