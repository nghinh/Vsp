// Shot Tracking Service — VSP Mobile App
//
// Coordinates active shot tracking during a live round.
// Follows the 2-tap flow: tap to start shot, tap to end shot.
//
// Per Story 10.3 — Slice 2: UI — Shot Entry
//
// Responsibilities:
//  1. Start shot: capture GPS start location, persist via ShotSyncService
//  2. End shot: capture GPS end location, calculate lie/distance, persist
//  3. Active shot state: stream of current active shot for UI indicators
//  4. GPS accuracy: expose accuracy badge state during capture

import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/models/shot.dart';
import '../../domain/services/lie_detector.dart';
import '../../domain/models/sync_status.dart';
import '../../domain/services/location_service.dart';
import '../../domain/value_objects/lat_lng.dart';
import '../services/shot_sync_service.dart';

/// State of the active shot tracking session.
enum ShotTrackingState {
  /// No active shot — idle.
  idle,

  /// Shot has been started, waiting for end tap.
  shotActive,

  /// Shot ended, persisting locally.
  persisting,

  /// Shot persisted and enqueued for sync.
  persisted,

  /// Error during shot tracking.
  error,
}

/// Result of ending a shot.
class ShotEndResult {
  final Shot shot;
  final LieDetectionResult lieDetection;
  final double? distanceYards;
  final double? distanceMeters;
  final String? conditionsSnapshot;

  const ShotEndResult({
    required this.shot,
    required this.lieDetection,
    this.distanceYards,
    this.distanceMeters,
    this.conditionsSnapshot,
  });
}

/// Service coordinating active shot tracking during a round.
///
/// Follows the 2-tap flow:
///  1. [startShot] — captures GPS start location, persists ShotStarted event
///  2. [endShot] — captures GPS end location, calculates lie/distance, persists ShotEnded event
///
/// Emits [ShotTrackingState] updates via [trackingStateStream].
///
/// Per Story 10.3 Slice 2.
class ShotTrackingService {
  final ShotSyncService _shotSyncService;
  final LocationService _locationService;
  final Uuid _uuid = const Uuid();

  ShotTrackingService({
    required ShotSyncService shotSyncService,
    required LocationService locationService,
  }) : _shotSyncService = shotSyncService,
       _locationService = locationService;

  // ─── State ────────────────────────────────────────────────────────────────

  final _stateController = StreamController<ShotTrackingState>.broadcast();
  final _activeShotController = StreamController<Shot?>.broadcast();

  ShotTrackingState _currentState = ShotTrackingState.idle;
  Shot? _activeShot;

  /// Stream of tracking state changes.
  Stream<ShotTrackingState> get trackingStateStream => _stateController.stream;

  /// Stream of the current active shot (null when idle).
  Stream<Shot?> get activeShotStream => _activeShotController.stream;

  /// Current tracking state.
  ShotTrackingState get currentState => _currentState;

  /// Current active shot (null when idle).
  Shot? get activeShot => _activeShot;

  // ─── Shot Lifecycle ───────────────────────────────────────────────────────

  /// Start a new shot.
  ///
  /// Captures the current GPS location as the start point,
  /// persists locally, and enqueues a ShotStarted sync event.
  ///
  /// Returns the created shot.
  /// Throws if GPS is unavailable.
  Future<Shot> startShot({
    required String roundId,
    required String flightId,
    required String playerId,
    required int holeNumber,
    required int shotNumber,
    String? clubId,
  }) async {
    _setState(ShotTrackingState.persisting);

    try {
      // Capture GPS start location
      final location = await _locationService.getCurrentLocation();
      final startLocation = _locationToGeoJson(location);
      final confidence = _gpsConfidence(location);

      // Capture conditions snapshot
      final conditions = _captureConditions();

      final shot = await _shotSyncService.startShot(
        roundId: roundId,
        flightId: flightId,
        playerId: playerId,
        holeNumber: holeNumber,
        shotNumber: shotNumber,
        clubId: clubId,
        startedAt: DateTime.now(),
        startLocation: startLocation,
        conditions: conditions,
        confidence: confidence,
      );

      _activeShot = shot;
      _setState(ShotTrackingState.shotActive);
      _activeShotController.add(shot);

      return shot;
    } catch (e) {
      _setState(ShotTrackingState.error);
      rethrow;
    }
  }

  /// End the active shot.
  ///
  /// Captures the current GPS location as the end point,
  /// calculates lie and distance, persists locally,
  /// and enqueues a ShotEnded sync event.
  ///
  /// Returns [ShotEndResult] with the updated shot and detection results.
  /// Throws if no shot is active or GPS is unavailable.
  Future<ShotEndResult> endShot({
    required String? clubId,
    required LieDetectionResult Function(
      LatLng start,
      LatLng end,
      double accuracy,
    )
    lieDetector,
  }) async {
    if (_activeShot == null) {
      throw StateError('No active shot to end');
    }

    _setState(ShotTrackingState.persisting);

    try {
      // Capture GPS end location
      final location = await _locationService.getCurrentLocation();
      final endLocation = _locationToGeoJson(location);
      final accuracy = location.accuracyMeters ?? 10.0;

      // Parse start location
      final startLocation = _parseGeoJson(_activeShot!.startLocation);

      // Calculate distance
      double? distanceYards;
      double? distanceMeters;
      if (startLocation != null) {
        final distanceM = startLocation.distanceTo(
          LatLng(latitude: location.latitude, longitude: location.longitude),
        );
        distanceMeters = distanceM;
        distanceYards = distanceM * 1.09361; // meters to yards
      }

      // Detect lie
      final lieDetection = startLocation != null
          ? lieDetector(
              startLocation,
              LatLng(
                latitude: location.latitude,
                longitude: location.longitude,
              ),
              accuracy,
            )
          : LieDetectionResult(
              lie: ShotLie.other,
              confidence: 0.0,
              reason: 'No start location',
            );

      // Capture conditions snapshot
      final conditions = _captureConditions();

      final shot = await _shotSyncService.endShot(
        shotId: _activeShot!.id,
        endedAt: DateTime.now(),
        endLocation: endLocation,
        lie: lieDetection.lie,
        distanceYards: distanceYards,
        distanceMeters: distanceMeters,
        result: _inferResult(lieDetection.lie),
        conditions: conditions,
        confidence: lieDetection.confidence,
      );

      _activeShot = null;
      _setState(ShotTrackingState.persisted);
      _activeShotController.add(null);

      // Reset to idle after brief delay
      await Future.delayed(const Duration(milliseconds: 500));
      _setState(ShotTrackingState.idle);

      return ShotEndResult(
        shot: shot,
        lieDetection: lieDetection,
        distanceYards: distanceYards,
        distanceMeters: distanceMeters,
        conditionsSnapshot: conditions,
      );
    } catch (e) {
      _setState(ShotTrackingState.error);
      rethrow;
    }
  }

  /// Update the club assigned to the active shot.
  Future<Shot?> updateActiveShotClub(String clubId) async {
    if (_activeShot == null) return null;

    try {
      final updated = await _shotSyncService.editShot(
        shotId: _activeShot!.id,
        clubId: clubId,
      );
      _activeShot = updated;
      _activeShotController.add(updated);
      return updated;
    } catch (e) {
      return null;
    }
  }

  /// Cancel the active shot without persisting.
  Future<void> cancelActiveShot() async {
    if (_activeShot == null) return;

    try {
      await _shotSyncService.deleteShot(_activeShot!.id);
    } finally {
      _activeShot = null;
      _setState(ShotTrackingState.idle);
      _activeShotController.add(null);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _setState(ShotTrackingState state) {
    _currentState = state;
    _stateController.add(state);
  }

  String _locationToGeoJson(dynamic location) {
    return jsonEncode({
      'type': 'Point',
      'coordinates': [
        location.longitude,
        location.latitude,
        if (location.altitudeMeters != null) location.altitudeMeters,
      ],
    });
  }

  LatLng? _parseGeoJson(String? geoJson) {
    if (geoJson == null) return null;
    try {
      final map = jsonDecode(geoJson) as Map<String, dynamic>;
      final coords = map['coordinates'] as List<dynamic>;
      return LatLng(
        latitude: (coords[1] as num).toDouble(),
        longitude: (coords[0] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  double _gpsConfidence(dynamic location) {
    final accuracy = (location.accuracyMeters as num?)?.toDouble() ?? 10.0;
    if (accuracy <= 5) return 0.95;
    if (accuracy <= 10) return 0.85;
    if (accuracy <= 20) return 0.70;
    if (accuracy <= 30) return 0.50;
    return 0.30;
  }

  String? _captureConditions() {
    // Conditions snapshot: wind, temp, humidity from weather service
    // Stored as JSON string in the shot.conditions field
    // Per Story 10.3 spec: conditions snapshot at shot time
    return null; // TODO: Integrate with weather service
  }

  ShotResult? _inferResult(ShotLie lie) {
    switch (lie) {
      case ShotLie.fairway:
        return ShotResult.fairwayHit;
      case ShotLie.green:
        return ShotResult.greenHit;
      case ShotLie.bunker:
        return ShotResult.inBunker;
      case ShotLie.water:
        return ShotResult.inWater;
      case ShotLie.outOfBounds:
        return ShotResult.outOfBounds;
      case ShotLie.penalty:
        return ShotResult.penalty;
      default:
        return null;
    }
  }

  /// Dispose resources.
  void dispose() {
    _stateController.close();
    _activeShotController.close();
  }
}
