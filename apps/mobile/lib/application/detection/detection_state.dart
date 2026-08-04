// Detection State — VSP Mobile App
//
// Story 6.2 — Wave E: Integration & Offline
// Story 6.2 — Wave F: Observability & Accessibility
//
// State for DetectionCubit tracking detection status and result.

import 'package:equatable/equatable.dart';

import '../../domain/models/course_hole_detection.dart';
import '../../domain/models/qualified_location.dart';

/// Detection service lifecycle status.
enum DetectionStatus {
  /// No active round, detection not started.
  idle,

  /// Detection is active and monitoring location updates.
  active,

  /// Detection is paused (e.g., round paused).
  paused,

  /// Detection encountered an error.
  error,
}

/// State for the detection cubit.
///
/// Tracks:
/// - [status]: service lifecycle
/// - [currentDetection]: latest detection result
/// - [currentLocation]: location used for current detection
/// - [pendingSwitch]: true if a hole switch is suggested but pending user confirmation
/// - [error]: error message if status is error
class DetectionState extends Equatable {
  /// Current detection lifecycle status.
  final DetectionStatus status;

  /// Latest detection result (may be null if no detection yet).
  final CourseHoleDetectionResult? currentDetection;

  /// Location used for the current detection.
  final QualifiedLocation? currentLocation;

  /// True if a hole switch is suggested but requires user confirmation.
  final bool pendingSwitch;

  /// Suggested hole number for pending switch.
  final int? suggestedHoleNumber;

  /// Error message if status is error.
  final String? error;

  const DetectionState({
    required this.status,
    this.currentDetection,
    this.currentLocation,
    this.pendingSwitch = false,
    this.suggestedHoleNumber,
    this.error,
  });

  /// Initial idle state.
  factory DetectionState.initial() {
    return const DetectionState(status: DetectionStatus.idle);
  }

  /// Convenience getters for UI.
  bool get isActive => status == DetectionStatus.active;
  bool get isIdle => status == DetectionStatus.idle;
  bool get isPaused => status == DetectionStatus.paused;
  bool get isError => status == DetectionStatus.error;

  /// True if a valid hole is detected.
  bool get hasValidHole => currentDetection?.hasValidHole ?? false;

  /// True if auto-switch is enabled for the current detection.
  bool get canAutoSwitch => currentDetection?.canAutoSwitch ?? false;

  /// Current confidence level.
  ConfidenceLevel? get confidenceLevel => currentDetection?.level;

  /// Human-readable description of current detection quality.
  String get qualityDescription =>
      currentDetection?.qualityDescription ?? 'No detection yet';

  /// Current hole number, if detected.
  int? get currentHoleNumber => currentDetection?.holeNumber;

  DetectionState copyWith({
    DetectionStatus? status,
    CourseHoleDetectionResult? currentDetection,
    QualifiedLocation? currentLocation,
    bool? pendingSwitch,
    int? suggestedHoleNumber,
    String? error,
  }) {
    return DetectionState(
      status: status ?? this.status,
      currentDetection: currentDetection ?? this.currentDetection,
      currentLocation: currentLocation ?? this.currentLocation,
      pendingSwitch: pendingSwitch ?? this.pendingSwitch,
      suggestedHoleNumber: suggestedHoleNumber ?? this.suggestedHoleNumber,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentDetection,
    currentLocation,
    pendingSwitch,
    suggestedHoleNumber,
    error,
  ];
}
