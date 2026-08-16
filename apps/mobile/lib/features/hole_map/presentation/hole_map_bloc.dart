// HoleMapBloc — VSP Mobile App
//
// BLoC managing hole map state: loading geometry from local package,
// golfer position updates, target placement, and layer visibility.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../data/hole_map_repository.dart';
import 'package:vsp_mobile/data/services/round_telemetry_recorder.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/hole_map/data/course_pin_api.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_feature_api.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/domain/golfer_position_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/target_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/wind_relative_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/distance_ring_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/services/wind_relative_calculator.dart';
import 'hole_map_event.dart';
import 'hole_map_state.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// BLoC for the strategic hole map feature.
class HoleMapBloc extends Bloc<HoleMapEvent, HoleMapState> {
  final HoleMapRepository _repository;
  final LocationService? _locationService;
  final Uuid _uuid = const Uuid();
  final WindRelativeCalculator _windCalculator = WindRelativeCalculator();

  /// Records GPS quality and map load latency for the round, when there is a
  /// round to record against. Null outside one — opening a hole map from the
  /// course browser is not a round and has nothing to attribute records to.
  final RoundTelemetryRecorder? _telemetry;

  /// When the hole currently loading was asked for.
  ///
  /// Story 6.6 measures how long a hole takes to become usable, and this bloc
  /// is the only place that sees both ends of that: the request, and the state
  /// the screen can finally draw.
  DateTime? _loadStartedAt;

  StreamSubscription<QualifiedLocation>? _locationSubscription;

  String? _currentPackageId;
  String? _currentCourseId;
  String? _currentCourseName;
  int? _currentHoleNumber;

  /// Latest usable GPS fix, kept verbatim.
  ///
  /// [GolferPositionEntity] drops the fix's own uncertainty vocabulary, and
  /// anything quoting a distance from the golfer needs it to state an error
  /// bar. Null until a fix that is actually a position arrives.
  QualifiedLocation? _lastFix;

  /// The golfer's last usable GPS fix, or null when there is none.
  QualifiedLocation? get lastFix => _lastFix;

  /// Hole this bloc has loaded, or null before the first load.
  ///
  /// The round owns one bloc for the whole round and creates it lazily, so a
  /// golfer who reaches the 5th before opening the map finds a bloc that was
  /// never told about holes 2 to 5. Whatever puts a hole on screen compares
  /// against this to know whether it has to say so.
  int? get loadedHoleNumber => _currentHoleNumber;

  /// Reads the club's published flag positions. Null in tests and wherever
  /// the network has no business being reached.
  final CoursePinApi? _pinApi;

  /// Reads the shapes a vision model traced from satellite imagery. Most
  /// holes here have no surveyed polygons at all, so this is usually the
  /// only geometry there is.
  final HoleFeatureApi? _featureApi;

  HoleMapBloc({
    required HoleMapRepository repository,
    LocationService? locationService,
    RoundTelemetryRecorder? telemetry,
    CoursePinApi? pinApi,
    HoleFeatureApi? featureApi,
  }) : _repository = repository,
       _locationService = locationService,
       _telemetry = telemetry,
       _pinApi = pinApi,
       _featureApi = featureApi,
       super(const HoleMapInitial()) {
    on<LoadHoleMap>(_onLoadHoleMap);
    on<UpdateGolferPosition>(_onUpdateGolferPosition);
    on<UpdateTarget>(_onUpdateTarget);
    on<ClearTarget>(_onClearTarget);
    on<ToggleLayerVisibility>(_onToggleLayerVisibility);
    on<NavigateToHole>(_onNavigateToHole);
    on<RetryLoadHoleMap>(_onRetryLoadHoleMap);
    _subscribeToLocation();
  }

  /// Follows the golfer for as long as this bloc lives.
  ///
  /// Nothing used to feed [UpdateGolferPosition], so the map's golfer position
  /// was permanently null and every distance derived from it was unavailable.
  /// The subscription starts with the bloc, which is created lazily when the
  /// golfer first opens a tab that needs a position — not at round start.
  void _subscribeToLocation() {
    final service = _locationService;
    if (service == null) return;
    service.start();
    _locationSubscription = service.locationStream.listen(
      _onFix,
      onError: (_) {
        // A failed fix is not a crash. Whatever is on screen already knows how
        // to say "no GPS"; keep the last known position rather than throwing.
      },
    );
    final existing = service.lastLocation;
    if (existing != null) _onFix(existing);
  }

  void _onFix(QualifiedLocation location) {
    if (isClosed) return;
    // An "unavailable" fix carries 0,0 — the Gulf of Guinea. Recording it would
    // put the golfer 10,000 km from the hole and quote a distance for it.
    if (location.source == LocationSource.unavailable) return;
    _lastFix = location;
    // Recorded, not requested: this bloc subscribes to a stream the round is
    // already running, so telemetry costs no extra GPS. Throttled inside the
    // recorder, and awaited by nobody — a slow insert must not delay the
    // position the map is about to draw.
    _telemetry?.recordFix(location);
    add(
      UpdateGolferPosition(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracyMeters,
      ),
    );
  }

  Future<void> _onLoadHoleMap(
    LoadHoleMap event,
    Emitter<HoleMapState> emit,
  ) async {
    _loadStartedAt = DateTime.now().toUtc();
    emit(
      HoleMapLoading(
        courseName: event.courseName,
        holeNumber: event.holeNumber,
      ),
    );

    _telemetry?.setHole(event.holeNumber);
    _currentPackageId = event.packageId;
    _currentCourseId = event.courseId;
    _currentCourseName = event.courseName;
    _currentHoleNumber = event.holeNumber;

    // Whoever opened this screen may not know which package covers the course
    // — the course picker never did, and passed null unconditionally. Ask the
    // device before concluding there is nothing to draw.
    final packageId =
        event.packageId ??
        await _repository.findPackageIdForCourse(event.courseId);
    if (packageId != null) {
      _currentPackageId = packageId;
    }

    if (packageId == null) {
      // No package on the device. There is nothing to ask the repository for,
      // and no geometry is not a failure — it is most of our 900 holes.
      //
      // Not recorded as a map load: nothing was loaded. Timing a branch that
      // reads one null would fill the dataset with sub-millisecond rows and
      // flatter the average the 2 s target is measured against.
      emit(
        HoleMapUnsurveyed(
          courseName: event.courseName,
          holeNumber: event.holeNumber,
        ),
      );
      return;
    }

    try {
      final holeMap = await _repository.getHoleMap(
        packageId: packageId,
        courseId: event.courseId,
        courseName: event.courseName,
        holeNumber: event.holeNumber,
      );

      if (holeMap == null) {
        // A package that carries nothing for this hole is the same answer as
        // no package: unsurveyed, so satellite + measuring is what helps.
        _recordMapLoad(event.holeNumber);
        emit(
          HoleMapUnsurveyed(
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

      _recordMapLoad(event.holeNumber);
      // Build initial state — windRelative will be computed after position/target
      emit(HoleMapReady(holeMap: holeMap, layerVisibility: layerVisibility));

      // Then the traced shapes, where the package carried none. A hole with
      // a tee point and a green point draws as two dots; the same hole with
      // the model's greens, bunkers and water draws as golf.
      await _applyTracedFeatures(emit, event.courseId, event.holeNumber);

      // Then today's flag, if the club publishes one. After the map is on
      // screen and after the latency is recorded, on purpose: the pin is a
      // network read, and making the drawn hole wait for it would turn an
      // offline round's map into a spinner.
      await _applyTodaysPin(emit, event.courseId, event.holeNumber);
    } catch (e) {
      // A load that failed is not a load time. Recording it would put the
      // duration of an error next to the durations of successes and drag the
      // 2 s target's evidence around for reasons that have nothing to do with
      // rendering.
      _loadStartedAt = null;
      emit(
        HoleMapError(
          message: AppMessages.mapLoadFailed,
          courseName: event.courseName,
          holeNumber: event.holeNumber,
        ),
      );
    }
  }

  /// Adds the traced shapes to whatever the package already had.
  ///
  /// The package wins where it has a layer: a surveyed green is better than
  /// a traced one, and this must never quietly replace it. Everywhere else —
  /// which is most layers on most holes — the model's shapes are all there
  /// is.
  Future<void> _applyTracedFeatures(
    Emitter<HoleMapState> emit,
    String courseId,
    int holeNumber,
  ) async {
    final api = _featureApi;
    if (api == null) return;
    try {
      final traced = await api.forHole(
        courseId: courseId,
        holeNumber: holeNumber,
      );
      if (traced.isEmpty) {
        // Nothing has drawn this hole. Ask for it — one model call, gated by
        // the server — and pick the shapes up on the next open. Deliberately
        // not awaited into a spinner: the golfer wants the satellite view
        // now, and tracing takes seconds it should not owe them.
        await api.requestTrace(courseId: courseId, holeNumber: holeNumber);
        return;
      }
      if (emit.isDone) return;
      final current = state;
      if (current is! HoleMapReady) return;

      final merged = Map<MapLayerType, MapLayerEntity>.from(traced.layers);
      for (final entry in current.holeMap.layers.entries) {
        // The package wins where it has a shape — and only there.
        //
        // This used to be `addAll`, on the reading that a package layer beats
        // a traced one. It does. But every hole in every package carries a
        // `tee` and a `green` layer whether or not anybody digitised either:
        // the assembler seeds them with the hole's own two reference points.
        // So on every course whose polygons are still in the draft table —
        // which is all 62 of them — a one-point green layer overwrote the
        // green GolfSeg had just traced.
        //
        // Nothing looked broken. The green still had a position, the play line
        // still reached it, the header still read "Tới cờ 509 yd". What was
        // gone was its shape, and with it the front and back edges: the panel
        // that shows 505 / 530 needs three coordinates and had one, so it
        // rendered nothing at all rather than something wrong. A golfer was
        // being given the middle of the green and no way to tell it was the
        // middle.
        if (HoleGeometryCoverage.hasAreaGeometry(entry.value) ||
            !merged.containsKey(entry.key)) {
          merged[entry.key] = entry.value;
        }
      }
      final visibility = Map<String, bool>.from(current.layerVisibility);
      for (final layer in merged.keys) {
        visibility.putIfAbsent(layer.name, () => true);
      }

      emit(current.copyWith(
        holeMap: current.holeMap.copyWith(layers: merged),
        layerVisibility: visibility,
        // Only where a model drew something. Shapes a person digitised carry
        // their credit in the attribution line at the foot of the map, and
        // calling them unchecked machine output would be both untrue and a
        // good way to teach golfers to ignore the warning that is true.
        tracedShapesUnverified: traced.anyUnverified && traced.anyFromModel,
      ));
    } catch (_) {
      // Offline, or nothing traced for this hole. The map keeps whatever the
      // package gave it.
    }
  }

  /// Puts the club's published flag on the hole, when there is one.
  ///
  /// Quiet about every failure. A course with no greenkeeper on the portal,
  /// a phone with no signal on the 7th, and a pin whose window has closed are
  /// all the same answer — the hole draws with its geometry, as it did before
  /// any of this existed.
  Future<void> _applyTodaysPin(
    Emitter<HoleMapState> emit,
    String courseId,
    int holeNumber,
  ) async {
    final api = _pinApi;
    if (api == null) return;
    try {
      final pins = await api.forCourse(courseId);
      final pin = pins[holeNumber];
      if (pin == null || pin.isExpired || emit.isDone) return;
      final current = state;
      if (current is! HoleMapReady) return;
      emit(current.copyWith(holeMap: current.holeMap.copyWith(pin: pin)));
    } catch (_) {
      // Offline, or the course is not on the server. Nothing to say.
    }
  }

  /// Records how long this hole took to reach a state the screen can draw.
  ///
  /// This is the data half of map latency — the package read, not the frames
  /// MapLibre spends afterwards, which the bloc cannot see. Both are served
  /// from the on-device package, so `servedFromCache` is true: PRD §10.2's
  /// under-two-seconds target is a target for exactly this path.
  void _recordMapLoad(int holeNumber) {
    final recorder = _telemetry;
    final startedAt = _loadStartedAt;
    _loadStartedAt = null;
    if (recorder == null || startedAt == null) return;
    recorder.recordMapLoad(
      holeNumber: holeNumber,
      startedAt: startedAt,
      completedAt: DateTime.now().toUtc(),
      servedFromCache: true,
    );
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
      timestamp: _lastFix?.timestamp ?? DateTime.now(),
      isStale: _lastFix?.isStale ?? false,
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
    // A null package is a valid answer ("unsurveyed"), so only the identity of
    // the course gates navigation.
    if (_currentCourseId == null || _currentCourseName == null) {
      return;
    }

    add(
      LoadHoleMap(
        packageId: _currentPackageId,
        // The đường the caller named, where it named one. A round that
        // crosses from the front nine to the back changes course at hole 10,
        // and the hole number alone cannot say so.
        courseId: event.courseId ?? _currentCourseId!,
        courseName: _currentCourseName!,
        holeNumber: event.holeNumber,
      ),
    );
  }

  Future<void> _onRetryLoadHoleMap(
    RetryLoadHoleMap event,
    Emitter<HoleMapState> emit,
  ) async {
    if (_currentCourseId != null &&
        _currentCourseName != null &&
        _currentHoleNumber != null) {
      add(
        LoadHoleMap(
          packageId: _currentPackageId,
          courseId: _currentCourseId!,
          courseName: _currentCourseName!,
          holeNumber: _currentHoleNumber!,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    return super.close();
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
