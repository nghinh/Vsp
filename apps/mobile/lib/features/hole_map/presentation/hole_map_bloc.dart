// HoleMapBloc — VSP Mobile App
//
// BLoC managing hole map state: loading geometry from local package,
// golfer position updates, target placement, and layer visibility.

import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/golfer_position_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/target_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/wind_relative_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/distance_ring_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/services/wind_relative_calculator.dart';
import 'hole_map_event.dart';
import 'hole_map_state.dart';

/// BLoC for the strategic hole map feature.
class HoleMapBloc extends Bloc<HoleMapEvent, HoleMapState> {
  final HoleMapRepository _repository;
  final Uuid _uuid = const Uuid();
  final WindRelativeCalculator _windCalculator = WindRelativeCalculator();

  String? _currentPackageId;
  String? _currentCourseId;
  String? _currentCourseName;
  int? _currentHoleNumber;

  HoleMapBloc({required HoleMapRepository repository})
    : _repository = repository,
      super(const HoleMapInitial()) {
    on<LoadHoleMap>(_onLoadHoleMap);
    on<UpdateGolferPosition>(_onUpdateGolferPosition);
    on<UpdateTarget>(_onUpdateTarget);
    on<ClearTarget>(_onClearTarget);
    on<ToggleLayerVisibility>(_onToggleLayerVisibility);
    on<NavigateToHole>(_onNavigateToHole);
    on<RetryLoadHoleMap>(_onRetryLoadHoleMap);
  }

  Future<void> _onLoadHoleMap(
    LoadHoleMap event,
    Emitter<HoleMapState> emit,
  ) async {
    emit(
      HoleMapLoading(
        courseName: event.courseName,
        holeNumber: event.holeNumber,
      ),
    );

    _currentPackageId = event.packageId;
    _currentCourseId = event.courseId;
    _currentCourseName = event.courseName;
    _currentHoleNumber = event.holeNumber;

    try {
      final holeMap = await _repository.getHoleMap(
        packageId: event.packageId,
        courseId: event.courseId,
        courseName: event.courseName,
        holeNumber: event.holeNumber,
      );

      if (holeMap == null) {
        emit(
          HoleMapError(
            message: 'Hole geometry not found in course package',
            courseName: event.courseName,
            holeNumber: event.holeNumber,
          ),
        );
        return;
      }

      // Initialize default layer visibility — all geometry layers on
      final layerVisibility = <String, bool>{};
      for (final layer in holeMap.layers.keys) {
        layerVisibility[layer.name] = true;
      }

      // Build initial state — windRelative will be computed after position/target
      emit(HoleMapReady(holeMap: holeMap, layerVisibility: layerVisibility));
    } catch (e) {
      emit(
        HoleMapError(
          message: 'Failed to load hole map: $e',
          courseName: event.courseName,
          holeNumber: event.holeNumber,
        ),
      );
    }
  }

  void _onUpdateGolferPosition(
    UpdateGolferPosition event,
    Emitter<HoleMapState> emit,
  ) {
    final currentState = state;
    if (currentState is! HoleMapReady) return;

    final position = GolferPositionEntity(
      latitude: event.latitude,
      longitude: event.longitude,
      accuracy: event.accuracy,
      source: PositionSource.gps,
      confidence: _classifyAccuracy(event.accuracy),
      timestamp: DateTime.now(),
    );

    // Recompute distance rings from golfer position
    final rings = DistanceRingPresets.standardSet(
      centerLat: event.latitude,
      centerLng: event.longitude,
    );

    // Recompute wind relative with updated position
    final updatedState = currentState.copyWith(
      golferPosition: position,
      distanceRings: rings,
    );
    final windRelative = _computeWindRelative(updatedState);

    emit(updatedState.copyWith(windRelative: windRelative));
  }

  void _onUpdateTarget(UpdateTarget event, Emitter<HoleMapState> emit) {
    final currentState = state;
    if (currentState is! HoleMapReady) return;

    final target = TargetEntity(
      id: _uuid.v4(),
      latitude: event.latitude,
      longitude: event.longitude,
      createdAt: DateTime.now(),
      label: event.label,
    );

    final updatedState = currentState.copyWith(target: target);
    final windRelative = _computeWindRelative(updatedState);

    emit(updatedState.copyWith(windRelative: windRelative));
  }

  void _onClearTarget(ClearTarget event, Emitter<HoleMapState> emit) {
    final currentState = state;
    if (currentState is! HoleMapReady) return;

    // Build state without target and recompute wind relative
    final updatedState = HoleMapReady(
      holeMap: currentState.holeMap,
      golferPosition: currentState.golferPosition,
      target: null,
      wind: currentState.wind,
      windRelative: currentState.windRelative,
      distanceRings: currentState.distanceRings,
      layerVisibility: currentState.layerVisibility,
    );
    final windRelative = _computeWindRelative(updatedState);

    emit(updatedState.copyWith(windRelative: windRelative));
  }

  void _onToggleLayerVisibility(
    ToggleLayerVisibility event,
    Emitter<HoleMapState> emit,
  ) {
    final currentState = state;
    if (currentState is! HoleMapReady) return;

    final updatedVisibility = Map<String, bool>.from(
      currentState.layerVisibility,
    );
    updatedVisibility[event.layerId] = event.visible;

    emit(currentState.copyWith(layerVisibility: updatedVisibility));
  }

  Future<void> _onNavigateToHole(
    NavigateToHole event,
    Emitter<HoleMapState> emit,
  ) async {
    if (_currentPackageId == null ||
        _currentCourseId == null ||
        _currentCourseName == null) {
      return;
    }

    add(
      LoadHoleMap(
        packageId: _currentPackageId!,
        courseId: _currentCourseId!,
        courseName: _currentCourseName!,
        holeNumber: event.holeNumber,
      ),
    );
  }

  Future<void> _onRetryLoadHoleMap(
    RetryLoadHoleMap event,
    Emitter<HoleMapState> emit,
  ) async {
    if (_currentPackageId != null &&
        _currentCourseId != null &&
        _currentCourseName != null &&
        _currentHoleNumber != null) {
      add(
        LoadHoleMap(
          packageId: _currentPackageId!,
          courseId: _currentCourseId!,
          courseName: _currentCourseName!,
          holeNumber: _currentHoleNumber!,
        ),
      );
    }
  }

  PositionConfidence _classifyAccuracy(double? accuracyMetres) {
    if (accuracyMetres == null) return PositionConfidence.low;
    if (accuracyMetres <= 3) return PositionConfidence.high;
    if (accuracyMetres <= 10) return PositionConfidence.medium;
    return PositionConfidence.low;
  }

  /// Computes wind relative to the shot line.
  ///
  /// Shot line bearing is calculated from golfer position to target (if placed)
  /// or to the pin (as fallback). Returns null if wind data is unavailable or
  /// if golfer position is not yet known.
  WindRelativeEntity? _computeWindRelative(HoleMapReady state) {
    final wind = state.wind ?? state.holeMap.wind;
    if (wind == null) return null;

    final golfer = state.golferPosition;
    if (golfer == null) return null;

    // Target or pin as the aim point
    final aimLat = state.target?.latitude ?? state.holeMap.pin?.latitude;
    final aimLng = state.target?.longitude ?? state.holeMap.pin?.longitude;
    if (aimLat == null || aimLng == null) return null;

    final shotLineBearing = _calculateBearing(
      golfer.latitude,
      golfer.longitude,
      aimLat,
      aimLng,
    );

    return _windCalculator.calculate(
      wind: wind,
      shotLineBearingDegrees: shotLineBearing,
    );
  }

  /// Calculates the bearing (azimuth) from point A to point B.
  /// Returns bearing in degrees (0 = North, 90 = East, 180 = South, 270 = West).
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    // Convert to radians
    final lat1Rad = lat1 * _deg2rad;
    final lat2Rad = lat2 * _deg2rad;
    final dLng = (lng2 - lng1) * _deg2rad;

    // X = cos(lat2) * sin(dLng)
    // Y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
    final x = math.cos(lat2Rad) * math.sin(dLng);
    final y =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);

    var bearing = math.atan2(x, y) * _rad2deg;

    // Normalize to 0-360
    bearing = (bearing + 360) % 360;
    return bearing;
  }

  static const double _deg2rad = math.pi / 180;
  static const double _rad2deg = 180 / math.pi;
}
