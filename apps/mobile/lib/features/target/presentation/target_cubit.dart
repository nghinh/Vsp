// Target Cubit — VSP Mobile App
//
// Manages target placement, drag, and distance display.
// Computes ball→target and target→pin distances using Haversine
// (SRID 4326 → meters → unit conversion).
//
// Ball position is sourced from story 6.1 (stubbed until 6.1 lands).
// Pin position is sourced from story 6.4 (stubbed via fixture until 6.4 lands).
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../domain/target_model.dart';
import '../domain/target_repository.dart';
import 'target_state.dart';
import '../../../domain/services/location_service.dart';
import '../../../data/services/location_service_impl.dart';
import '../../../domain/models/qualified_location.dart';
import '../../hole_map/domain/pin_entity.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Pin position used for target distance maths.
///
/// Built from the real [PinEntity] on the hole (course package / pin service);
/// the class stays local so this cubit does not depend on the map feature's
/// widget layer.
class TargetPinPosition {
  final List<double> coordinates; // [lon, lat]
  final GpsAccuracy accuracy;
  final String source;

  const TargetPinPosition({
    required this.coordinates,
    required this.accuracy,
    required this.source,
  });

  /// Builds a pin position from the hole's real pin entity.
  factory TargetPinPosition.fromPin(PinEntity pin) => TargetPinPosition(
    coordinates: [pin.longitude, pin.latitude],
    accuracy: GpsAccuracy.high,
    source: pin.source.name,
  );
}

/// Ball position from the device GPS.
///
/// The golfer's ball is wherever they are standing, so the last qualified fix
/// from [LocationService] is the ball position. Returns null when there is no
/// usable fix — callers must not invent one.
class BallPositionProvider {
  final LocationService _locationService;

  BallPositionProvider({LocationService? locationService})
    : _locationService = locationService ?? LocationServiceImpl();

  /// `[lon, lat]` of the current fix, or null when GPS is unavailable.
  List<double>? getBallPosition() {
    final loc = _locationService.lastLocation;
    if (loc == null || loc.source == LocationSource.unavailable) return null;
    return [loc.longitude, loc.latitude];
  }

  /// GPS accuracy band of the current fix.
  GpsAccuracy getAccuracy() {
    final loc = _locationService.lastLocation;
    final accuracy = loc?.accuracyMeters;
    if (accuracy == null) return GpsAccuracy.low;
    if (accuracy <= 5) return GpsAccuracy.high;
    if (accuracy <= 15) return GpsAccuracy.medium;
    return GpsAccuracy.low;
  }
}

/// Calculates distances using Haversine formula on SRID 4326 coordinates.
class DistanceCalculator {
  static const double _earthRadiusMeters = 6371000.0;

  /// Compute distance in meters between two [lon, lat] coordinates.
  static double haversineDistanceMeters(List<double> from, List<double> to) {
    final lon1 = _toRadians(from[0]);
    final lat1 = _toRadians(from[1]);
    final lon2 = _toRadians(to[0]);
    final lat2 = _toRadians(to[1]);

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}

/// Cubit for target placement and distance management.
class TargetCubit extends Cubit<TargetState> {
  final TargetRepository _repository;
  final Uuid _uuid = const Uuid();

  /// Current round ID — set when round starts.
  String? _roundId;

  /// Current hole number — updated on hole change.
  int _holeNumber = 1;

  /// Ball position from the device GPS.
  final BallPositionProvider _ballPositionProvider;

  /// The hole's pin position, from the course package.
  TargetPinPosition? _pin;

  TargetCubit({
    required TargetRepository repository,
    BallPositionProvider? ballPositionProvider,
  }) : _repository = repository,
       _ballPositionProvider = ballPositionProvider ?? BallPositionProvider(),
       super(const TargetState.initial());

  /// Initialize for a round and hole.
  ///
  /// Call when round starts or hole changes.
  Future<void> initialize({
    required String roundId,
    required int holeNumber,
    TargetPinPosition? pin,
  }) async {
    _roundId = roundId;
    _holeNumber = holeNumber;
    _pin = pin;

    // Try to restore existing target from local store
    if (_roundId != null) {
      final existing = await _repository.getTarget(_roundId!, holeNumber);
      if (existing != null) {
        final distances = _computeDistances(existing);
        emit(
          state.copyWith(
            target: existing,
            distances: distances,
            clearError: true,
          ),
        );
      }
    }
  }

  /// Update hole number (called on hole change).
  Future<void> setHoleNumber(int holeNumber, {TargetPinPosition? pin}) async {
    _holeNumber = holeNumber;
    _pin = pin ?? _pin;

    // Try to restore target for new hole
    if (_roundId != null) {
      final existing = await _repository.getTarget(_roundId!, holeNumber);
      if (existing != null) {
        final distances = _computeDistances(existing);
        emit(
          state.copyWith(
            target: existing,
            distances: distances,
            clearError: true,
          ),
        );
      } else {
        emit(const TargetState.initial());
      }
    }
  }

  /// Place a target at the given map coordinates [lon, lat].
  Future<void> placeTarget(List<double> mapCoordinates) async {
    if (_roundId == null) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final accuracy = _ballPositionProvider.getAccuracy();
      final target = TargetModel.placed(
        id: 'target_${_roundId}_${_holeNumber}_${_uuid.v4()}',
        roundId: _roundId!,
        holeNumber: _holeNumber,
        position: mapCoordinates,
        accuracy: accuracy,
      );

      await _repository.saveTarget(target);

      final distances = _computeDistances(target);

      emit(
        state.copyWith(target: target, distances: distances, isLoading: false),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: AppMessages.targetActionFailed,
        ),
      );
    }
  }

  /// Move an existing target to new coordinates (called on drag end).
  Future<void> moveTarget(List<double> newCoordinates) async {
    if (state.target == null || _roundId == null) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final accuracy = _ballPositionProvider.getAccuracy();
      final moved = state.target!.moveTo(
        newPosition: newCoordinates,
        newAccuracy: accuracy,
      );

      await _repository.saveTarget(moved);

      final distances = _computeDistances(moved);

      emit(
        state.copyWith(target: moved, distances: distances, isLoading: false),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: AppMessages.targetActionFailed,
        ),
      );
    }
  }

  /// Enter drag mode (Slice 2).
  ///
  /// Called by UI when long-press is recognized on the target annotation.
  /// While in drag mode, map pan/zoom should be suppressed.
  void startDrag() {
    emit(state.copyWith(dragMode: TargetDragMode.dragging));
  }

  /// Exit drag mode (Slice 2).
  ///
  /// Called by UI when drag gesture ends (pointer released).
  /// Restores normal map pan/zoom behavior.
  void endDrag() {
    emit(state.copyWith(dragMode: TargetDragMode.none));
  }

  /// @deprecated Use [startDrag] / [endDrag] instead.
  /// Kept for backward compatibility with Slice 1 tests.
  // ignore: use_setters_to_change_properties
  void setDragging(bool dragging) {
    emit(
      state.copyWith(
        dragMode: dragging ? TargetDragMode.dragging : TargetDragMode.none,
      ),
    );
  }

  /// Clear the current target.
  Future<void> clearTarget() async {
    if (_roundId == null) return;

    try {
      await _repository.deleteTarget(_roundId!, _holeNumber);
      emit(const TargetState.initial());
    } catch (e) {
      emit(state.copyWith(errorMessage: AppMessages.targetActionFailed));
    }
  }

  /// Clear error message.
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  /// Compute ball→target and target→pin distances.
  ///
  /// Ball position is the current GPS fix; pin position comes from the hole's
  /// pin entity. Returns null when either is missing — a distance invented
  /// from a guessed position would mislead club selection.
  TargetDistances? _computeDistances(TargetModel target) {
    if (_pin == null) return null;

    final ballPos = _ballPositionProvider.getBallPosition();
    if (ballPos == null) return null;
    final pinPos = _pin!.coordinates;

    final ballToTarget = DistanceCalculator.haversineDistanceMeters(
      ballPos,
      target.position,
    );
    final targetToPin = DistanceCalculator.haversineDistanceMeters(
      target.position,
      pinPos,
    );

    return TargetDistances(
      ballToTargetMeters: ballToTarget,
      targetToPinMeters: targetToPin,
      unit: DistanceUnit.meters,
      accuracy: target.accuracy,
      timestamp: DateTime.now(),
    );
  }
}
