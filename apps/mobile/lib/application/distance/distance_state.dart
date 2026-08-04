// Distance State — VSP Mobile App
//
// Story 6.4 — Wave 2: State Management
//
// BLoC/Cubit state for distance calculations.
// Tracks golfer position, all green/hazard distances, and UI display state.

import 'package:equatable/equatable.dart';

import '../../domain/models/hole_geometry.dart';
import '../../domain/value_objects/distance_measurement.dart';
import '../../domain/value_objects/distance_type.dart';
import '../../domain/value_objects/lat_lng.dart';
import '../../features/profile/data/profile_dto.dart' show DistanceUnit;

/// Loading, error, and data state for distance calculations.
enum DistanceStatus {
  /// No round or hole geometry available.
  idle,

  /// Geometry loaded, waiting for first GPS position.
  waitingForLocation,

  /// Actively calculating distances.
  calculating,

  /// Distances available and current.
  ready,

  /// No hole geometry available for this hole.
  noHoleGeometry,

  /// GPS unavailable or too inaccurate.
  gpsUnavailable,
}

/// State for the distance cubit.
///
/// Combines:
/// - [status]: calculation lifecycle
/// - [golferPosition]: latest GPS position
/// - [gpsAccuracyMeters]: GPS accuracy at time of position
/// - [greenDistances]: front/center/back/pin measurements
/// - [hazardDistances]: per-hazard near/far/carry measurements
/// - [obDistance]: OB distance if applicable
/// - [targetDistance]: ball-to-target (from story 6.5)
/// - [targetToPinDistance]: target-to-pin (from story 6.5)
/// - [selectedUnit]: display unit (meters/yards)
/// - [loading]: loading flag for initial setup
/// - [error]: error message if status is error
class DistanceState extends Equatable {
  /// Current calculation lifecycle status.
  final DistanceStatus status;

  /// Latest golfer GPS position.
  final LatLng? golferPosition;

  /// GPS accuracy in meters at the time of [golferPosition].
  final double? gpsAccuracyMeters;

  /// Timestamp of the last distance calculation.
  final DateTime? timestamp;

  /// Hole geometry for the current hole.
  final HoleGeometry? holeGeometry;

  /// Green distances: front/center/back/pin.
  final Map<DistanceType, DistanceMeasurement> greenDistances;

  /// Hazard distances: hazardId → (DistanceType → DistanceMeasurement).
  final Map<String, Map<DistanceType, DistanceMeasurement>> hazardDistances;

  /// OB distance, if OB areas are present on the hole.
  final DistanceMeasurement? obDistance;

  /// Ball-to-target distance (null if no target placed — story 6.5).
  final DistanceMeasurement? targetDistance;

  /// Target-to-pin distance (null if no target — story 6.5).
  final DistanceMeasurement? targetToPinDistance;

  /// Selected display unit.
  final DistanceUnit selectedUnit;

  /// True if loading initial hole geometry.
  final bool loading;

  /// Error message, if [status] is error.
  final String? errorMessage;

  const DistanceState({
    this.status = DistanceStatus.idle,
    this.golferPosition,
    this.gpsAccuracyMeters,
    this.timestamp,
    this.holeGeometry,
    this.greenDistances = const {},
    this.hazardDistances = const {},
    this.obDistance,
    this.targetDistance,
    this.targetToPinDistance,
    this.selectedUnit = DistanceUnit.meters,
    this.loading = false,
    this.errorMessage,
  });

  /// Initial idle state.
  factory DistanceState.initial() {
    return const DistanceState();
  }

  // ─── Convenience getters ───────────────────────────────────────────────────

  /// True if distances are available and current.
  bool get hasDistances => status == DistanceStatus.ready;

  /// True if GPS is available (not gpsUnavailable).
  bool get hasGps =>
      status != DistanceStatus.gpsUnavailable && golferPosition != null;

  /// GPS accuracy level for color coding.
  GpsAccuracyLevel? get accuracyLevel {
    if (gpsAccuracyMeters == null) return null;
    if (gpsAccuracyMeters! < 5) return GpsAccuracyLevel.excellent;
    if (gpsAccuracyMeters! < 10) return GpsAccuracyLevel.good;
    if (gpsAccuracyMeters! < 20) return GpsAccuracyLevel.moderate;
    return GpsAccuracyLevel.poor;
  }

  /// True if GPS accuracy is good enough for on-course distances (<= 10m).
  bool get isGpsAcceptable =>
      gpsAccuracyMeters != null && gpsAccuracyMeters! <= 10;

  /// True if GPS accuracy warrants an amber/red warning (>= 10m).
  bool get hasAccuracyWarning =>
      gpsAccuracyMeters != null && gpsAccuracyMeters! >= 10;

  /// True if a target has been placed (story 6.5).
  bool get hasTarget => targetDistance != null;

  /// Front green distance, if available.
  DistanceMeasurement? get frontGreen =>
      greenDistances[DistanceType.frontGreen];

  /// Center green distance, if available.
  DistanceMeasurement? get centerGreen =>
      greenDistances[DistanceType.centerGreen];

  /// Back green distance, if available.
  DistanceMeasurement? get backGreen => greenDistances[DistanceType.backGreen];

  /// Pin distance, if available.
  DistanceMeasurement? get pinDistance => greenDistances[DistanceType.pin];

  /// Whether any hazard distances are available on the current hole.
  bool get hasHazardDistances => hazardDistances.isNotEmpty;

  /// All hazard IDs present on the current hole.
  List<String> get hazardIds => hazardDistances.keys.toList();

  /// Get all distance measurements for a specific hazard.
  Map<DistanceType, DistanceMeasurement>? hazardById(String id) =>
      hazardDistances[id];

  /// Aggregate confidence: minimum confidence across all green distances.
  double? get aggregateConfidence {
    if (greenDistances.isEmpty) return null;
    return greenDistances.values
        .map((m) => m.confidence)
        .reduce((a, b) => a < b ? a : b);
  }

  /// Confidence level label derived from aggregate confidence.
  ConfidenceLevel? get confidenceLevel {
    final c = aggregateConfidence;
    if (c == null) return null;
    if (c >= 0.9) return ConfidenceLevel.high;
    if (c >= 0.7) return ConfidenceLevel.medium;
    if (c >= 0.5) return ConfidenceLevel.low;
    return ConfidenceLevel.veryLow;
  }

  // ─── Mutators ─────────────────────────────────────────────────────────────

  /// Copy with updated fields.
  DistanceState copyWith({
    DistanceStatus? status,
    LatLng? golferPosition,
    double? gpsAccuracyMeters,
    DateTime? timestamp,
    HoleGeometry? holeGeometry,
    Map<DistanceType, DistanceMeasurement>? greenDistances,
    Map<String, Map<DistanceType, DistanceMeasurement>>? hazardDistances,
    DistanceMeasurement? obDistance,
    DistanceMeasurement? targetDistance,
    DistanceMeasurement? targetToPinDistance,
    DistanceUnit? selectedUnit,
    bool? loading,
    String? errorMessage,
    // Explicitly clear target when cleared
    bool clearTarget = false,
    bool clearOb = false,
  }) {
    return DistanceState(
      status: status ?? this.status,
      golferPosition: golferPosition ?? this.golferPosition,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      timestamp: timestamp ?? this.timestamp,
      holeGeometry: holeGeometry ?? this.holeGeometry,
      greenDistances: greenDistances ?? this.greenDistances,
      hazardDistances: hazardDistances ?? this.hazardDistances,
      obDistance: clearOb ? null : (obDistance ?? this.obDistance),
      targetDistance: clearTarget
          ? null
          : (targetDistance ?? this.targetDistance),
      targetToPinDistance: clearTarget
          ? null
          : (targetToPinDistance ?? this.targetToPinDistance),
      selectedUnit: selectedUnit ?? this.selectedUnit,
      loading: loading ?? this.loading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    golferPosition,
    gpsAccuracyMeters,
    timestamp,
    holeGeometry,
    greenDistances,
    hazardDistances,
    obDistance,
    targetDistance,
    targetToPinDistance,
    selectedUnit,
    loading,
    errorMessage,
  ];
}
