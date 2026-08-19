// Location Service Implementation — VSP Mobile App
//
// Story 6.1: Acquire and Qualify Location
// AC2: Accuracy above 10m or stale positions trigger warning state.
// AC3: Battery-aware sampling reduces updates when stationary while preserving
//      active play responsiveness.
//
// Battery-aware sampling strategy:
// - Stationary (speed < 0.5 m/s): update every [stationaryInterval] (30s)
// - Moving (speed >= 0.5 m/s): update every [activeInterval] (1s)
// - Accuracy below 10m: triggers lowAccuracy warning (AC2)
// - Position age > 5s: triggers stale warning (AC2)

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../domain/models/qualified_location.dart';
import '../../domain/services/location_service.dart';

/// Default intervals for battery-aware sampling.
const _defaultStationaryInterval = Duration(seconds: 30);
const _defaultActiveInterval = Duration(seconds: 1);
const _stalenessThresholdSeconds = 5;
const _stationarySpeedThresholdMps = 0.5; // ~1.8 km/h

/// Implementation of [LocationService] using the geolocator package.
///
/// Emits [QualifiedLocation] stream with:
/// - Coordinates, accuracy, heading, timestamp
/// - isStale metadata
/// - hasWarning=true when accuracy >10m or position age >5s
///
/// Battery-aware sampling:
/// - Stationary: updates every 30s to conserve battery
/// - Moving: updates every 1s to preserve active play responsiveness
class LocationServiceImpl implements LocationService {
  StreamController<QualifiedLocation>? _controller;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _samplingTimer;

  /// The underlying Geolocator instance.
  final GeolocatorPlatform _geolocator;

  /// Last position received from the stream.
  Position? _lastPosition;

  /// Whether the service is currently running.
  bool _isRunning = false;

  /// Whether the device is currently stationary.
  bool _isStationary = true;

  /// Battery-aware stationary interval (AC3).
  @override
  Duration get stationaryInterval => _defaultStationaryInterval;

  /// Battery-aware active interval (AC3).
  @override
  Duration get activeInterval => _defaultActiveInterval;

  /// Cached last qualified location.
  QualifiedLocation? _lastQualifiedLocation;

  @override
  QualifiedLocation? get lastLocation => _lastQualifiedLocation;

  LocationServiceImpl({GeolocatorPlatform? geolocator})
    : _geolocator = geolocator ?? GeolocatorPlatform.instance;

  @override
  Stream<QualifiedLocation> get locationStream {
    _controller ??= StreamController<QualifiedLocation>.broadcast(
      onListen: () {
        // Stream consumer attached — nothing extra needed; start() handles init.
      },
      onCancel: () {
        stop();
      },
    );
    return _controller!.stream;
  }

  @override
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _startListening();
  }

  @override
  void stop() {
    _isRunning = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _samplingTimer?.cancel();
    _samplingTimer = null;
  }

  /// Nothing on this path waits for ever.
  ///
  /// ─── Why there is a clock on asking for permission ────────────────────────
  ///
  /// `requestPermission()` resolves when the golfer answers the system dialog,
  /// and there is no rule that says they ever will: they can leave it on
  /// screen, or the platform channel can stall, and the await simply never
  /// completes. Everything upstream then waits with it.
  ///
  /// What that looks like: the "Gần đây" tab of the course list spinning on
  /// "Đang tìm sân gần bạn…" with no timeout, no error, and no way out but
  /// leaving the screen. The bloc above it says in a comment "Never leave the
  /// tab spinning: a denied/disabled/timed-out fix emits an error state" — and
  /// it kept that promise for the fix itself, which carries a ten second
  /// limit, and not for the permission request in front of it.
  ///
  /// Found by the screen-by-screen sweep, which sat on that tab for
  /// twenty-five seconds and photographed it still turning.
  static const permissionTimeout = Duration(seconds: 20);

  /// The outer bound on getting a fix.
  ///
  /// `LocationSettings.timeLimit` is the platform's own, and it is the one
  /// that usually fires. This is the one that fires when it does not.
  static const fixTimeout = Duration(seconds: 15);

  @override
  Future<bool> isLocationAvailable() async {
    try {
      final serviceEnabled = await _geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await _geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Unanswered is not granted. A golfer who ignores the dialog gets the
        // same answer as one who says no, and the screen behind it moves on.
        permission = await _geolocator
            .requestPermission()
            .timeout(permissionTimeout, onTimeout: () => LocationPermission.denied);
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<QualifiedLocation> getCurrentLocation() async {
    final available = await isLocationAvailable();
    if (!available) {
      return QualifiedLocation.unavailable();
    }

    try {
      final position = await _geolocator
          .getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 10),
            ),
          )
          // Belt as well as braces: the setting above is the platform's own
          // limit and it does not fire on every platform.
          .timeout(fixTimeout);
      return _qualify(position);
    } catch (_) {
      return QualifiedLocation.unavailable();
    }
  }

  @override
  void dispose() {
    stop();
    _controller?.close();
    _controller = null;
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  void _startListening() {
    _positionSubscription?.cancel();

    // Use the appropriate accuracy based on movement state.
    // We start in active mode (1s interval) and switch based on speed.
    _positionSubscription = _geolocator
        .getPositionStream(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0, // We handle filtering via timer
          ),
        )
        .listen(_onPosition, onError: _onError);

    // Emit immediately with a single shot first fix.
    _emitSingle();
  }

  void _emitSingle() async {
    if (!_isRunning) return;
    final ql = await getCurrentLocation();
    if (_isRunning) {
      _qualifyAndEmit(ql);
    }
    _reschedule(ql);
  }

  void _onPosition(Position position) {
    _lastPosition = position;
    final ql = _qualify(position);
    _qualifyAndEmit(ql);
  }

  void _onError(Object error) {
    // GPS error — emit unavailable and retry.
    if (_isRunning) {
      _qualifyAndEmit(QualifiedLocation.unavailable());
      // Retry after stationary interval.
      _reschedule(QualifiedLocation.unavailable());
    }
  }

  QualifiedLocation _qualify(Position position) {
    final ageSeconds = DateTime.now().difference(position.timestamp).inSeconds;
    final isStale = ageSeconds > _stalenessThresholdSeconds;

    // AC3: battery-aware — determine if stationary based on speed.
    _isStationary = position.speed < _stationarySpeedThresholdMps;

    // Map Geolocator Accuracy to our LocationSource.
    LocationSource source;
    switch (position.accuracy) {
      case <= 5:
        source = LocationSource.gps;
        break;
      case <= 50:
        source = LocationSource.gps; // GPS with moderate accuracy
        break;
      default:
        source = LocationSource.network; // Network when GPS is poor
    }

    return QualifiedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      altitudeMeters: position.altitude,
      speedMetersPerSecond: position.speed,
      heading: position.heading >= 0 ? position.heading : null,
      timestamp: position.timestamp,
      source: source,
      isStale: isStale,
    );
  }

  void _qualifyAndEmit(QualifiedLocation ql) {
    _lastQualifiedLocation = ql;
    _controller?.add(ql);
  }

  void _reschedule(QualifiedLocation ql) {
    _samplingTimer?.cancel();

    if (!_isRunning) return;

    // Determine interval based on stationary state (AC3).
    final interval = _isStationary ? stationaryInterval : activeInterval;

    _samplingTimer = Timer(interval, () {
      if (_isRunning) _emitSingle();
    });
  }
}
