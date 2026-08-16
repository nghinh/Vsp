// Measure Cubit — VSP Mobile App
//
// Owns the measuring tool's points and keeps the GPS origin fresh.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/measure_calculator.dart';
import 'package:vsp_mobile/features/measure/domain/measure_point.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

import 'measure_state.dart';

/// Manages the manual measuring tool.
///
/// Tapping empty map drops a point; tapping an existing point removes it.
class MeasureCubit extends Cubit<MeasureState> {
  final MeasureCalculator _calculator;
  final LocationService? _locationService;
  final Uuid _uuid;

  StreamSubscription<QualifiedLocation>? _locationSubscription;

  MeasureCubit({
    MeasureCalculator calculator = const MeasureCalculator(),
    LocationService? locationService,
    MeasureAnchor? green,
    DistanceUnit unit = DistanceUnit.meters,
    QualifiedLocation? initialOrigin,
    Uuid uuid = const Uuid(),
  }) : _calculator = calculator,
       _locationService = locationService,
       _uuid = uuid,
       super(
         MeasureState(
           green: green,
           unit: unit,
           origin: initialOrigin ?? locationService?.lastLocation,
         ),
       ) {
    _recompute();
    _subscribeToLocation();
  }

  void _subscribeToLocation() {
    final service = _locationService;
    if (service == null) return;
    service.start();
    _locationSubscription = service.locationStream.listen(
      updateOrigin,
      onError: (_) {
        // A failed fix is not a crash — the panel already knows how to say
        // "no GPS". Swallow and keep the last known origin.
      },
    );
  }

  /// Records a new GPS fix.
  void updateOrigin(QualifiedLocation location) {
    if (isClosed) return;
    emit(state.copyWith(origin: location));
    _recompute();
  }

  /// Sets the green/pin anchor for this hole.
  void setGreen(MeasureAnchor? green) {
    if (isClosed) return;
    emit(
      MeasureState(
        points: state.points,
        origin: state.origin,
        green: green,
        unit: state.unit,
        result: state.result,
      ),
    );
    _recompute();
  }

  /// Switches the display unit.
  void setUnit(DistanceUnit unit) {
    if (isClosed || state.unit == unit) return;
    emit(state.copyWith(unit: unit));
  }

  /// Toggles the golfer's display unit between metres and yards.
  void toggleUnit() {
    setUnit(
      state.unit == DistanceUnit.meters
          ? DistanceUnit.yards
          : DistanceUnit.meters,
    );
  }

  /// Handles a tap at [position].
  ///
  /// Removes the nearest existing point when the tap lands within
  /// [hitThresholdMeters] of one; otherwise appends a new point.
  void handleTap(LatLng position, {required double hitThresholdMeters}) {
    final hit = MeasureHitTester.findNearest(
      points: state.points,
      tap: position,
      thresholdMeters: hitThresholdMeters,
    );
    if (hit != null) {
      removePoint(hit.id);
    } else {
      addPoint(position);
    }
  }

  /// Appends a point at [position].
  void addPoint(LatLng position) {
    if (isClosed) return;
    final points = [
      ...state.points,
      MeasurePoint(id: _uuid.v4(), position: position),
    ];
    emit(state.copyWith(points: List.unmodifiable(points)));
    _recompute();
  }

  /// Moves the point with [id] to [position].
  ///
  /// A tap that lands a metre off used to mean deleting the point and dropping
  /// a new one, which loses its place in the chain: a mis-tapped second point
  /// came back as the last, and the legs the golfer had measured re-ordered
  /// themselves. Moving keeps the order.
  void movePoint(String id, LatLng position) {
    if (isClosed) return;
    if (!state.points.any((p) => p.id == id)) return;
    final points = [
      for (final point in state.points)
        if (point.id == id) point.copyWith(position: position) else point,
    ];
    emit(state.copyWith(points: List.unmodifiable(points)));
    _recompute();
  }

  /// Removes the point with [id].
  void removePoint(String id) {
    if (isClosed) return;
    final points = state.points.where((p) => p.id != id).toList();
    if (points.length == state.points.length) return;
    emit(state.copyWith(points: List.unmodifiable(points)));
    _recompute();
  }

  /// Replaces the chain with a suggested one.
  ///
  /// The plan arrives as ordinary points, deliberately. Everything the golfer
  /// can already do to a point they dropped themselves — drag it off the
  /// bunker, delete the layup and play the hole in two, tap to put one back —
  /// works on these without a line of new code, because there is nothing
  /// special about them once they are here. A suggestion the golfer cannot
  /// argue with is worse than no suggestion; this one is an opening offer.
  ///
  /// The last aim point is the target itself and is left off: the tool already
  /// measures the last leg to the green, and a point sitting on the flag would
  /// be a marker the golfer has to delete before the number reads right.
  void applyPlan(List<LatLng> aimPoints) {
    if (isClosed) return;
    final points = [
      for (final position in aimPoints)
        MeasurePoint(id: _uuid.v4(), position: position),
    ];
    emit(state.copyWith(points: List.unmodifiable(points)));
    _recompute();
  }

  /// Removes the most recently dropped point.
  void undo() {
    if (isClosed || state.points.isEmpty) return;
    removePoint(state.points.last.id);
  }

  /// Clears every dropped point.
  void clear() {
    if (isClosed || state.points.isEmpty) return;
    emit(state.copyWith(points: const []));
    _recompute();
  }

  void _recompute() {
    if (isClosed) return;
    emit(
      state.copyWith(
        result: _calculator.compute(
          points: state.points,
          origin: state.origin,
          green: state.green,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    return super.close();
  }
}
