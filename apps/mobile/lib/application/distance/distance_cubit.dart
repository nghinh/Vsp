// Distance Cubit — VSP Mobile App
//
// Story 6.4 — Wave 2: State Management
//
// Listens to GPS location stream and calculates all distances on each update.
// AC: distances update within 1 second of location update (no debounce).
//
// Dependencies:
// - LocationProvider: location stream from Story 6.1 (QualifiedLocation stream)
// - HoleGeometryProvider: current hole geometry from Story 6.3 (or round data)
// - TargetProvider: optional target position from Story 6.5
//
// State flow:
// idle → waitingForLocation → (calculating → ready) | gpsUnavailable | noHoleGeometry

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/hole_geometry.dart';
import '../../domain/services/distance_calculator.dart';
import '../../domain/value_objects/distance_measurement.dart';
import '../../domain/value_objects/distance_type.dart';
import '../../domain/value_objects/lat_lng.dart';
import '../../features/profile/data/profile_dto.dart' show DistanceUnit;
import 'distance_state.dart';

/// Cubit for distance calculation state management.
///
/// Usage:
/// ```dart
/// // Create with dependencies
/// final cubit = DistanceCubit(
///   locationStream: locationCubit.stream,
///   calculator: DistanceCalculator(),
/// );
///
/// // Provide to widget tree
/// BlocProvider.value(value: cubit, child: MyWidget()),
/// ```
class DistanceCubit extends Cubit<DistanceState> {
  /// Calculator service for all distance computations.
  final DistanceCalculator _calculator;

  /// Stream subscription to the location cubit stream.
  StreamSubscription<dynamic>? _locationSubscription;

  /// Current hole geometry (set when round starts or hole changes).
  HoleGeometry? _currentHole;

  DistanceCubit({
    required Stream<dynamic> locationStream,
    required DistanceCalculator calculator,
    DistanceUnit initialUnit = DistanceUnit.meters,
  }) : _calculator = calculator,
       super(DistanceState(selectedUnit: initialUnit)) {
    // Subscribe to location updates
    _locationSubscription = locationStream.listen(_onLocationUpdate);
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Set the current hole geometry and trigger recalculation.
  ///
  /// Called when the active hole changes (story 6.2 hole detection).
  void setHoleGeometry(HoleGeometry? hole) {
    _currentHole = hole;
    if (hole == null) {
      emit(
        state.copyWith(
          status: DistanceStatus.noHoleGeometry,
          holeGeometry: null,
          greenDistances: {},
          hazardDistances: {},
          clearOb: true,
        ),
      );
      return;
    }

    // If we already have a position, recalculate immediately
    if (state.golferPosition != null) {
      _recalculate();
    } else {
      emit(
        state.copyWith(
          status: DistanceStatus.waitingForLocation,
          holeGeometry: hole,
        ),
      );
    }
  }

  /// Toggle the display unit between meters and yards.
  void toggleUnit() {
    final newUnit = state.selectedUnit == DistanceUnit.meters
        ? DistanceUnit.yards
        : DistanceUnit.meters;
    emit(state.copyWith(selectedUnit: newUnit));
  }

  /// Set the display unit explicitly.
  void setUnit(DistanceUnit unit) {
    if (state.selectedUnit != unit) {
      emit(state.copyWith(selectedUnit: unit));
    }
  }

  /// Set a target position and calculate ball-to-target and target-to-pin.
  ///
  /// Called by Story 6.5 when user places a target on the map.
  void setTarget(LatLng targetPosition) {
    if (_currentHole == null || state.golferPosition == null) return;

    final targetDistance = _calculator.calculateTargetDistance(
      golferPosition: state.golferPosition!,
      targetPosition: targetPosition,
      gpsAccuracyMeters: state.gpsAccuracyMeters ?? 5.0,
      timestamp: DateTime.now(),
    );

    final targetToPin = _calculator.calculateTargetToPinDistance(
      targetPosition: targetPosition,
      pinPosition: _currentHole!.pinPosition,
      gpsAccuracyMeters: state.gpsAccuracyMeters ?? 5.0,
      timestamp: DateTime.now(),
    );

    emit(
      state.copyWith(
        targetDistance: targetDistance,
        targetToPinDistance: targetToPin,
      ),
    );
  }

  /// Clear the current target.
  void clearTarget() {
    emit(state.copyWith(clearTarget: true));
  }

  /// Stop the cubit and cancel subscriptions.
  void stop() {
    _locationSubscription?.cancel();
    emit(state.copyWith(status: DistanceStatus.idle));
  }

  // ─── Location handling ─────────────────────────────────────────────────────

  /// Handle incoming location updates from LocationCubit.
  ///
  /// Per AC: update distances within 1 second of location update (no debounce).
  void _onLocationUpdate(dynamic locationEvent) {
    // Support both QualifiedLocation and raw LatLng
    LatLng? position;
    double? accuracy;

    if (locationEvent is LatLng) {
      position = locationEvent;
      accuracy = 5.0; // default assumption
    } else if (locationEvent is Map) {
      // Flexible map-based location (e.g. from repository)
      position = locationEvent['position'] as LatLng?;
      accuracy = locationEvent['accuracy'] as double?;
    } else {
      // Try to extract via reflection-like access
      position = _extractPosition(locationEvent);
      accuracy = _extractAccuracy(locationEvent);
    }

    if (position == null) {
      emit(
        state.copyWith(
          status: DistanceStatus.gpsUnavailable,
          golferPosition: null,
          gpsAccuracyMeters: null,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: DistanceStatus.calculating,
        golferPosition: position,
        gpsAccuracyMeters: accuracy,
        timestamp: DateTime.now(),
      ),
    );

    // Recalculate distances synchronously (no debounce — AC requirement)
    _recalculateWith(position: position, accuracy: accuracy ?? 5.0);
  }

  LatLng? _extractPosition(dynamic event) {
    try {
      // Try qualified_location shape
      if (event.position != null) return event.position as LatLng?;
      if (event.currentLocation != null) {
        final loc = event.currentLocation;
        if (loc.position != null) return loc.position as LatLng?;
      }
      // Try map shape
      if (event is Map) {
        final pos = event['position'];
        if (pos is LatLng) return pos;
        if (pos is Map) {
          return LatLng(
            latitude: (pos['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (pos['longitude'] as num?)?.toDouble() ?? 0,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  double? _extractAccuracy(dynamic event) {
    try {
      if (event.accuracy != null) return (event.accuracy as num).toDouble();
      if (event.currentLocation != null) {
        final loc = event.currentLocation;
        if (loc.accuracy != null) return (loc.accuracy as num).toDouble();
        if (loc.gpsAccuracyMeters != null) {
          return (loc.gpsAccuracyMeters as num).toDouble();
        }
      }
      if (event is Map) {
        return (event['accuracy'] as num?)?.toDouble();
      }
    } catch (_) {}
    return null;
  }

  // ─── Core calculation ──────────────────────────────────────────────────────

  /// Recalculate all distances for the current hole and position.
  ///
  /// Called synchronously after each location update (no debounce).
  void _recalculate() {
    _recalculateWith(
      position: state.golferPosition!,
      accuracy: state.gpsAccuracyMeters ?? 5.0,
    );
  }

  void _recalculateWith({required LatLng position, required double accuracy}) {
    if (_currentHole == null) {
      emit(state.copyWith(status: DistanceStatus.noHoleGeometry));
      return;
    }

    final timestamp = DateTime.now();
    final hole = _currentHole!;

    // Green distances
    final greens = _calculator.calculateGreenDistances(
      golferPosition: position,
      hole: hole,
      gpsAccuracyMeters: accuracy,
      timestamp: timestamp,
    );

    // Hazard distances
    final hazards = hole.hazards.isNotEmpty
        ? _calculator.calculateHazardDistances(
            golferPosition: position,
            hazards: hole.hazards,
            gpsAccuracyMeters: accuracy,
            timestamp: timestamp,
            hole: hole,
          )
        : <String, Map<DistanceType, DistanceMeasurement>>{};

    // OB distance
    DistanceMeasurement? obDist;
    if (hole.obAreas.isNotEmpty) {
      obDist = _calculator.calculateObDistance(
        golferPosition: position,
        obAreas: hole.obAreas,
        gpsAccuracyMeters: accuracy,
        timestamp: timestamp,
      );
    }

    emit(
      state.copyWith(
        status: DistanceStatus.ready,
        greenDistances: greens,
        hazardDistances: hazards,
        obDistance: obDist,
        clearOb: hole.obAreas.isEmpty,
        timestamp: timestamp,
      ),
    );
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
