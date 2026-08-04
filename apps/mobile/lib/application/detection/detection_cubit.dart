// Detection Cubit — VSP Mobile App
//
// Story 6.2 — Wave E: Integration & Offline
// Story 6.2 — Wave F: Observability & Accessibility
//
// Integrates the QualifiedLocation stream from LocationCubit (6.1)
// with CourseHoleDetectionService for automatic course/hole detection.
//
// Features:
// - Listens to location updates and triggers detection
// - Caches last detection for offline restart
// - Manages pending hole switch confirmations
// - Emits telemetry events for observability

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/course_hole_detection.dart';
import '../../domain/models/manual_hole_selection.dart';
import '../../domain/models/qualified_location.dart';
import '../../domain/services/course_hole_detection_service.dart';
import '../../features/play/services/course_hole_detection_service_impl.dart';
import '../location/location_state.dart';
import 'detection_state.dart';

/// Cubit for course/hole detection management.
///
/// Integrates with LocationCubit for location updates and
/// CourseHoleDetectionService for detection logic.
///
/// Usage:
/// ```dart
/// // Start detection for a round
/// context.read<DetectionCubit>().startDetection(roundId);
///
/// // Subscribe to state for UI updates
/// ```
class DetectionCubit extends Cubit<DetectionState> {
  final CourseHoleDetectionService _detectionService;

  /// Active round ID.
  String? _activeRoundId;

  /// Location state subscription.
  StreamSubscription<LocationState>? _locationSubscription;

  /// Last detected hole number (to detect hole transitions).
  int? _lastDetectedHole;

  /// Callback for telemetry events.
  final void Function(DetectionTelemetryEvent)? onTelemetry;

  DetectionCubit({
    required CourseHoleDetectionService detectionService,
    void Function(DetectionTelemetryEvent)? onTelemetry,
  }) : _detectionService = detectionService,
       onTelemetry = onTelemetry,
       super(DetectionState.initial());

  /// Start detection for a round.
  ///
  /// [roundId] - Active round ID for context and caching.
  /// [locationStateStream] - Stream of location states from LocationCubit.
  Future<void> startDetection(
    String roundId,
    Stream<LocationState> locationStateStream,
  ) async {
    if (_activeRoundId == roundId) return;

    _activeRoundId = roundId;

    // Cancel any existing subscription
    await _locationSubscription?.cancel();

    // Set up detection service for this round
    if (_detectionService is CourseHoleDetectionServiceImpl) {
      (_detectionService as CourseHoleDetectionServiceImpl).setActiveRound(
        roundId,
      );
    }

    // Restore cached detection if available
    final cached = await _detectionService.getLastKnownDetection(roundId);
    if (cached != null) {
      _lastDetectedHole = cached.holeNumber;
      emit(
        state.copyWith(
          status: DetectionStatus.active,
          currentDetection: cached,
          currentLocation: null,
        ),
      );
    } else {
      emit(state.copyWith(status: DetectionStatus.active));
    }

    // Subscribe to location updates
    _locationSubscription = locationStateStream.listen(_onLocationState);
  }

  /// Stop detection and release resources.
  Future<void> stopDetection() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _activeRoundId = null;
    _lastDetectedHole = null;

    if (_detectionService is CourseHoleDetectionServiceImpl) {
      (_detectionService as CourseHoleDetectionServiceImpl).clearActiveRound();
    }

    emit(DetectionState.initial());
  }

  /// Apply a manual hole selection.
  ///
  /// Called when user explicitly chooses a hole.
  Future<void> applyManualSelection({
    required String holeId,
    required ManualSelectionReason reason,
    required QualifiedLocation location,
  }) async {
    if (_activeRoundId == null) return;

    await _detectionService.applyManualSelection(
      location: location,
      roundId: _activeRoundId!,
      selectedHoleId: holeId,
      reason: reason,
    );

    _lastDetectedHole = null; // Will be updated on next detection

    // Clear pending switch state
    emit(state.copyWith(pendingSwitch: false, suggestedHoleNumber: null));

    // Emit telemetry for manual selection
    _emitTelemetry(DetectionTelemetryEventType.manualSelection, holeId: holeId);
  }

  /// Confirm a pending hole switch.
  ///
  /// Called after user confirms the switch in the confirmation dialog.
  Future<void> confirmHoleSwitch(int holeNumber) async {
    if (!state.pendingSwitch || state.suggestedHoleNumber == null) return;

    // Apply manual selection with the suggested hole
    await applyManualSelection(
      holeId: 'hole_$holeNumber', // TODO(6.2): Use actual hole ID from geometry
      reason: ManualSelectionReason.promptedByLowConfidence,
      location: state.currentLocation ?? QualifiedLocation.unavailable(),
    );

    _lastDetectedHole = holeNumber;

    emit(state.copyWith(pendingSwitch: false, suggestedHoleNumber: null));

    _emitTelemetry(
      DetectionTelemetryEventType.holeSwitchConfirmed,
      holeNumber: holeNumber,
    );
  }

  /// Cancel a pending hole switch.
  ///
  /// Called when user cancels the switch in the confirmation dialog.
  void cancelHoleSwitch() {
    emit(state.copyWith(pendingSwitch: false, suggestedHoleNumber: null));

    _emitTelemetry(DetectionTelemetryEventType.holeSwitchCancelled);
  }

  /// Pause detection (e.g., when round is paused).
  void pauseDetection() {
    if (state.status != DetectionStatus.active) return;
    emit(state.copyWith(status: DetectionStatus.paused));
  }

  /// Resume detection after pause.
  void resumeDetection() {
    if (state.status != DetectionStatus.paused) return;
    emit(state.copyWith(status: DetectionStatus.active));
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  void _onLocationState(LocationState locationState) {
    if (state.status != DetectionStatus.active) return;

    final location = locationState.currentLocation;
    if (location == null) return;

    _detect(location);
  }

  Future<void> _detect(QualifiedLocation location) async {
    if (_activeRoundId == null) return;

    try {
      final result = await _detectionService.detect(
        location: location,
        roundId: _activeRoundId!,
      );

      // Check if hole changed
      final holeChanged =
          result.holeNumber != null &&
          _lastDetectedHole != null &&
          result.holeNumber != _lastDetectedHole;

      _lastDetectedHole = result.holeNumber;

      // Determine if we need to show confirmation dialog
      bool pendingSwitch = false;
      int? suggestedHoleNumber;

      if (holeChanged && result.canAutoSwitch) {
        // Auto-switch enabled - no confirmation needed
        _emitTelemetry(
          DetectionTelemetryEventType.autoSwitch,
          holeNumber: result.holeNumber,
          confidence: result.confidence,
        );
      } else if (holeChanged && !result.canAutoSwitch && result.hasValidHole) {
        // Auto-switch blocked - show confirmation dialog
        pendingSwitch = true;
        suggestedHoleNumber = result.holeNumber;

        _emitTelemetry(
          DetectionTelemetryEventType.suggestedHoleSwitch,
          holeNumber: result.holeNumber,
          confidence: result.confidence,
          level: result.level,
        );
      }

      emit(
        state.copyWith(
          currentDetection: result,
          currentLocation: location,
          pendingSwitch: pendingSwitch,
          suggestedHoleNumber: suggestedHoleNumber,
        ),
      );

      // Emit telemetry for detection
      _emitTelemetry(
        DetectionTelemetryEventType.detectionUpdated,
        holeNumber: result.holeNumber,
        confidence: result.confidence,
        level: result.level,
      );
    } catch (e) {
      emit(state.copyWith(status: DetectionStatus.error, error: e.toString()));

      _emitTelemetry(
        DetectionTelemetryEventType.error,
        errorMessage: e.toString(),
      );
    }
  }

  void _emitTelemetry(
    DetectionTelemetryEventType type, {
    int? holeNumber,
    double? confidence,
    ConfidenceLevel? level,
    String? holeId,
    String? errorMessage,
  }) {
    if (onTelemetry == null) return;

    onTelemetry!(
      DetectionTelemetryEvent(
        type: type,
        roundId: _activeRoundId,
        holeNumber: holeNumber,
        confidence: confidence,
        level: level,
        holeId: holeId,
        errorMessage: errorMessage,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}

/// Types of telemetry events for detection.
enum DetectionTelemetryEventType {
  /// Detection result updated.
  detectionUpdated,

  /// Auto-switch occurred (no confirmation needed).
  autoSwitch,

  /// Hole switch suggested but blocked (pending confirmation).
  suggestedHoleSwitch,

  /// User confirmed the hole switch.
  holeSwitchConfirmed,

  /// User cancelled the hole switch.
  holeSwitchCancelled,

  /// User manually selected a hole.
  manualSelection,

  /// Detection error occurred.
  error,
}

/// Telemetry event for detection.
class DetectionTelemetryEvent {
  final DetectionTelemetryEventType type;
  final String? roundId;
  final int? holeNumber;
  final double? confidence;
  final ConfidenceLevel? level;
  final String? holeId;
  final String? errorMessage;
  final DateTime timestamp;

  const DetectionTelemetryEvent({
    required this.type,
    this.roundId,
    this.holeNumber,
    this.confidence,
    this.level,
    this.holeId,
    this.errorMessage,
    required this.timestamp,
  });
}
