// Shot Detection Domain Models — VSP Mobile App
//
// Domain models for automatic shot detection with multi-signal confidence scoring.
//
// Signal types (per architecture and slice plan):
//   - gps: GPS movement delta (weight: 0.30)
//   - accelerometer: accelerometer movement signature (weight: 0.25, combined with gyroscope)
//   - gyroscope: gyroscope movement signature (weight: 0.25, combined with accelerometer)
//   - time: time interval since last shot (weight: 0.15)
//   - holeContext: proximity to hole features (weight: 0.20)
//
// Confidence levels (score boundaries per AC2):
//   - discard: 0.0–0.2
//   - reviewLater: 0.2–0.5
//   - confirm: 0.5–0.75
//   - automatic: 0.75–1.0
//
// Filter types (per AC3):
//   - practiceSwing, cartMovement, nearbyGolfer, shortShot, penalty, mulligan
//
// Story 10.4 — Slice 1: Domain Models

import 'package:equatable/equatable.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

/// Types of signals used for shot detection.
///
/// 5 canonical signal types covering sensor, GPS, movement, time, and
/// hole context signals per AC1.
enum ShotDetectionSignalType {
  /// GPS movement delta — distance traveled in detection window.
  /// Weight: 0.30
  gps,

  /// Accelerometer movement signature — swing-like vs cart vs walking.
  /// Weight: 0.25 (combined with gyroscope)
  accelerometer,

  /// Gyroscope movement signature — swing rotation pattern.
  /// Weight: 0.25 (combined with accelerometer)
  gyroscope,

  /// Time interval since last shot — typical shot pacing by hole.
  /// Weight: 0.15
  time,

  /// Hole context proximity — proximity to green/tee/landing zones.
  /// Weight: 0.20
  holeContext;

  /// Human-readable label for UI display.
  String get displayLabel {
    switch (this) {
      case ShotDetectionSignalType.gps:
        return 'GPS Movement';
      case ShotDetectionSignalType.accelerometer:
        return 'Accelerometer';
      case ShotDetectionSignalType.gyroscope:
        return 'Gyroscope';
      case ShotDetectionSignalType.time:
        return 'Time Interval';
      case ShotDetectionSignalType.holeContext:
        return 'Hole Context';
    }
  }

  /// Default weight for this signal type.
  /// Note: accelerometer and gyroscope are combined with weight 0.25 each
  /// and should be treated as a unit for scoring purposes.
  double get defaultWeight {
    switch (this) {
      case ShotDetectionSignalType.gps:
        return 0.30;
      case ShotDetectionSignalType.accelerometer:
        return 0.125;
      case ShotDetectionSignalType.gyroscope:
        return 0.125;
      case ShotDetectionSignalType.time:
        return 0.15;
      case ShotDetectionSignalType.holeContext:
        return 0.20;
    }
  }
}

/// Confidence level for shot detection results.
///
/// Determines whether a shot is auto-accepted, requires review, confirmation,
/// or should be discarded per AC2.
enum ShotConfidenceLevel {
  /// 0.75–1.0: Auto-accept the shot suggestion.
  automatic,

  /// 0.5–0.75: Suggest to user for confirmation.
  confirm,

  /// 0.2–0.5: Flag for later review.
  reviewLater,

  /// 0.0–0.2: Discard the suggestion.
  discard;

  /// Human-readable label for UI display.
  String get displayLabel {
    switch (this) {
      case ShotConfidenceLevel.automatic:
        return 'Auto-Accept';
      case ShotConfidenceLevel.confirm:
        return 'Confirm';
      case ShotConfidenceLevel.reviewLater:
        return 'Review Later';
      case ShotConfidenceLevel.discard:
        return 'Discard';
    }
  }

  /// Derive ShotConfidenceLevel from a numeric confidence score.
  ///
  /// Score boundaries per AC2:
  ///   - discard: 0.0–0.2
  ///   - reviewLater: 0.2–0.5
  ///   - confirm: 0.5–0.75
  ///   - automatic: 0.75–1.0
  static ShotConfidenceLevel fromScore(double score) {
    if (score >= 0.75) return ShotConfidenceLevel.automatic;
    if (score >= 0.5) return ShotConfidenceLevel.confirm;
    if (score >= 0.2) return ShotConfidenceLevel.reviewLater;
    return ShotConfidenceLevel.discard;
  }

  /// Minimum score for this confidence level.
  double get minScore {
    switch (this) {
      case ShotConfidenceLevel.automatic:
        return 0.75;
      case ShotConfidenceLevel.confirm:
        return 0.5;
      case ShotConfidenceLevel.reviewLater:
        return 0.2;
      case ShotConfidenceLevel.discard:
        return 0.0;
    }
  }

  /// Maximum score for this confidence level.
  double get maxScore {
    switch (this) {
      case ShotConfidenceLevel.automatic:
        return 1.0;
      case ShotConfidenceLevel.confirm:
        return 0.75;
      case ShotConfidenceLevel.reviewLater:
        return 0.5;
      case ShotConfidenceLevel.discard:
        return 0.2;
    }
  }
}

/// Categories of false-positive shots that should be filtered out.
///
/// 6 exclusion categories covering practice swings, cart movement,
/// nearby golfers, short shots, penalties, and mulligans per AC3.
enum ShotFilterType {
  /// Practice swing: no GPS movement delta + accelerometer swing
  /// signature + within teeing ground.
  practiceSwing,

  /// Cart movement: continuous GPS movement + low accelerometer
  /// variance + on cart path.
  cartMovement,

  /// Nearby golfer: multiple GPS points within 5m with diverging
  /// trajectories.
  nearbyGolfer,

  /// Short shot: movement delta < 10m AND proximity to green
  /// indicates putt.
  shortShot,

  /// Penalty: sudden GPS jump > 50m without corresponding club swing.
  penalty,

  /// Mulligan: movement delta large but confidence very low AND
  /// player initiated.
  mulligan;

  /// Human-readable label for UI display.
  String get displayLabel {
    switch (this) {
      case ShotFilterType.practiceSwing:
        return 'Practice Swing';
      case ShotFilterType.cartMovement:
        return 'Cart Movement';
      case ShotFilterType.nearbyGolfer:
        return 'Nearby Golfer';
      case ShotFilterType.shortShot:
        return 'Short Shot';
      case ShotFilterType.penalty:
        return 'Penalty';
      case ShotFilterType.mulligan:
        return 'Mulligan';
    }
  }

  /// Human-readable reason for exclusion.
  String get exclusionReason {
    switch (this) {
      case ShotFilterType.practiceSwing:
        return 'Detected as practice swing — no shot recorded';
      case ShotFilterType.cartMovement:
        return 'Detected as cart movement — no shot recorded';
      case ShotFilterType.nearbyGolfer:
        return 'Detected as nearby golfer activity';
      case ShotFilterType.shortShot:
        return 'Detected as short putt — filtered';
      case ShotFilterType.penalty:
        return 'Detected as penalty — excluded from normal shot flow';
      case ShotFilterType.mulligan:
        return 'Detected as mulligan — player-initiated retry';
    }
  }
}

/// Status of a shot detection suggestion.
enum ShotDetectionSuggestionStatus {
  /// Suggestion is pending user review.
  pending,

  /// Suggestion was confirmed by user.
  confirmed,

  /// Suggestion was rejected by user.
  rejected,

  /// Suggestion was automatically discarded.
  discarded;

  static ShotDetectionSuggestionStatus fromString(String? value) {
    if (value == null) return ShotDetectionSuggestionStatus.pending;
    return ShotDetectionSuggestionStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ShotDetectionSuggestionStatus.pending,
    );
  }
}

// ─── Value Objects ───────────────────────────────────────────────────────────

/// A single signal captured during a detection window.
///
/// Value object representing a single signal's type, value, weight,
/// and normalized score.
class ShotDetectionSignal extends Equatable {
  /// Type of this signal.
  final ShotDetectionSignalType type;

  /// Raw value from the sensor.
  /// - GPS: distance in meters
  /// - Accelerometer: acceleration magnitude in m/s²
  /// - Gyroscope: rotation rate in rad/s
  /// - Time: seconds since last shot
  /// - Hole context: proximity score 0.0–1.0
  final double rawValue;

  /// Weight assigned to this signal (0.0–1.0).
  final double weight;

  /// Normalized score for this signal (0.0–1.0).
  final double normalizedScore;

  /// When this signal was captured.
  final DateTime capturedAt;

  const ShotDetectionSignal({
    required this.type,
    required this.rawValue,
    required this.weight,
    required this.normalizedScore,
    required this.capturedAt,
  });

  /// Create a signal with default weight from type.
  factory ShotDetectionSignal.withDefaultWeight({
    required ShotDetectionSignalType type,
    required double rawValue,
    required double normalizedScore,
    required DateTime capturedAt,
  }) {
    return ShotDetectionSignal(
      type: type,
      rawValue: rawValue,
      weight: type.defaultWeight,
      normalizedScore: normalizedScore,
      capturedAt: capturedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'rawValue': rawValue,
    'weight': weight,
    'normalizedScore': normalizedScore,
    'capturedAt': capturedAt.toIso8601String(),
  };

  factory ShotDetectionSignal.fromJson(Map<String, dynamic> json) {
    return ShotDetectionSignal(
      type: ShotDetectionSignalType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ShotDetectionSignalType.gps,
      ),
      rawValue: (json['rawValue'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      normalizedScore: (json['normalizedScore'] as num).toDouble(),
      capturedAt: DateTime.parse(json['capturedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    type,
    rawValue,
    weight,
    normalizedScore,
    capturedAt,
  ];
}

/// Bundle of all signals captured during a single detection window.
class ShotDetectionSignals extends Equatable {
  /// GPS signal. Null if not available.
  final ShotDetectionSignal? gps;

  /// Accelerometer signal. Null if not available.
  final ShotDetectionSignal? accelerometer;

  /// Gyroscope signal. Null if not available.
  final ShotDetectionSignal? gyroscope;

  /// Time interval signal. Null if not available.
  final ShotDetectionSignal? time;

  /// Hole context proximity signal. Null if not available.
  final ShotDetectionSignal? holeContext;

  /// When these signals were captured.
  final DateTime capturedAt;

  /// Detection window duration in seconds.
  final int windowSeconds;

  const ShotDetectionSignals({
    this.gps,
    this.accelerometer,
    this.gyroscope,
    this.time,
    this.holeContext,
    required this.capturedAt,
    this.windowSeconds = 30,
  });

  /// Get a signal by type.
  ShotDetectionSignal? signalFor(ShotDetectionSignalType type) {
    switch (type) {
      case ShotDetectionSignalType.gps:
        return gps;
      case ShotDetectionSignalType.accelerometer:
        return accelerometer;
      case ShotDetectionSignalType.gyroscope:
        return gyroscope;
      case ShotDetectionSignalType.time:
        return time;
      case ShotDetectionSignalType.holeContext:
        return holeContext;
    }
  }

  /// All non-null signals as a list.
  List<ShotDetectionSignal> get allSignals {
    return [
      gps,
      accelerometer,
      gyroscope,
      time,
      holeContext,
    ].whereType<ShotDetectionSignal>().toList();
  }

  /// True if all required signals are present.
  bool get isComplete =>
      gps != null &&
      accelerometer != null &&
      gyroscope != null &&
      time != null &&
      holeContext != null;

  Map<String, dynamic> toJson() => {
    'gps': gps?.toJson(),
    'accelerometer': accelerometer?.toJson(),
    'gyroscope': gyroscope?.toJson(),
    'time': time?.toJson(),
    'holeContext': holeContext?.toJson(),
    'capturedAt': capturedAt.toIso8601String(),
    'windowSeconds': windowSeconds,
  };

  factory ShotDetectionSignals.fromJson(Map<String, dynamic> json) {
    return ShotDetectionSignals(
      gps: json['gps'] != null
          ? ShotDetectionSignal.fromJson(json['gps'] as Map<String, dynamic>)
          : null,
      accelerometer: json['accelerometer'] != null
          ? ShotDetectionSignal.fromJson(
              json['accelerometer'] as Map<String, dynamic>,
            )
          : null,
      gyroscope: json['gyroscope'] != null
          ? ShotDetectionSignal.fromJson(
              json['gyroscope'] as Map<String, dynamic>,
            )
          : null,
      time: json['time'] != null
          ? ShotDetectionSignal.fromJson(json['time'] as Map<String, dynamic>)
          : null,
      holeContext: json['holeContext'] != null
          ? ShotDetectionSignal.fromJson(
              json['holeContext'] as Map<String, dynamic>,
            )
          : null,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      windowSeconds: (json['windowSeconds'] as num?)?.toInt() ?? 30,
    );
  }

  @override
  List<Object?> get props => [
    gps,
    accelerometer,
    gyroscope,
    time,
    holeContext,
    capturedAt,
    windowSeconds,
  ];
}

// ─── Models ──────────────────────────────────────────────────────────────────

/// Result of a shot detection evaluation.
///
/// Contains all suggestions sorted by confidence, the detection location,
/// and metadata about the detection window.
class ShotDetectionResult extends Equatable {
  final List<ShotDetectionSuggestion> _suggestions;

  /// Suggestions sorted by confidence (highest first).
  List<ShotDetectionSuggestion> get suggestions {
    final sorted = List<ShotDetectionSuggestion>.of(_suggestions)
      ..sort((a, b) => (b.confidence as num).compareTo(a.confidence as num));
    return List<ShotDetectionSuggestion>.unmodifiable(sorted);
  }

  /// When detection was evaluated.
  final DateTime detectedAt;

  /// Center point of the detection window as GeoJSON Point string.
  final String? location;

  /// Filter types that were applied to reach these suggestions.
  final List<ShotFilterType> filtersApplied;

  const ShotDetectionResult({
    required List<ShotDetectionSuggestion> suggestions,
    required this.detectedAt,
    this.location,
    this.filtersApplied = const [],
  }) : _suggestions = suggestions;

  /// True if any suggestion has automatic confidence.
  bool get hasAutomaticSuggestion =>
      suggestions.any((s) => s.level == ShotConfidenceLevel.automatic);

  /// True if any suggestion requires confirmation.
  bool get hasConfirmSuggestion =>
      suggestions.any((s) => s.level == ShotConfidenceLevel.confirm);

  /// True if all suggestions should be reviewed later or discarded.
  bool get needsReview => suggestions.every(
    (s) =>
        s.level == ShotConfidenceLevel.reviewLater ||
        s.level == ShotConfidenceLevel.discard,
  );

  /// The top suggestion (highest confidence) or null if empty.
  ShotDetectionSuggestion? get topSuggestion =>
      suggestions.isNotEmpty ? suggestions.first : null;

  Map<String, dynamic> toJson() => {
    'suggestions': suggestions.map((s) => s.toJson()).toList(),
    'detectedAt': detectedAt.toIso8601String(),
    'location': location,
    'filtersApplied': filtersApplied.map((f) => f.name).toList(),
  };

  factory ShotDetectionResult.fromJson(Map<String, dynamic> json) {
    return ShotDetectionResult(
      suggestions: (json['suggestions'] as List? ?? const [])
          .map(
            (s) => ShotDetectionSuggestion.fromJson(s as Map<String, dynamic>),
          )
          .toList(),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      location: json['location'] as String?,
      filtersApplied:
          (json['filtersApplied'] as List?)
              ?.map(
                (f) => ShotFilterType.values.firstWhere(
                  (t) => t.name == f,
                  orElse: () => ShotFilterType.practiceSwing,
                ),
              )
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [
    suggestions,
    detectedAt,
    location,
    filtersApplied,
  ];
}

/// A shot detection suggestion awaiting user confirmation.
///
/// Per slice plan: shotId (pending), playerId, clubId?, suggestedLie,
/// suggestedStartLocation, suggestedEndLocation?, confidence, level,
/// signals, reason, detectedAt, status.
class ShotDetectionSuggestion extends Equatable {
  /// Unique ID for this suggestion. Generated client-side.
  final String id;

  /// Round this suggestion belongs to.
  final String roundId;

  /// Player this suggestion is for.
  final String playerId;

  /// Suggested club ID (null until assigned).
  final String? clubId;

  /// Suggested lie at shot end.
  final String? suggestedLie;

  /// Start location as GeoJSON Point string.
  final String? suggestedStartLocation;

  /// End location as GeoJSON Point string (null for putts).
  final String? suggestedEndLocation;

  /// Confidence score 0.0–1.0.
  final double confidence;

  /// Confidence level bucket.
  final ShotConfidenceLevel level;

  /// Signals used to generate this suggestion.
  final ShotDetectionSignals signals;

  /// Human-readable reason for this suggestion.
  final String reason;

  /// When this shot was detected.
  final DateTime detectedAt;

  /// Current status of this suggestion.
  final ShotDetectionSuggestionStatus status;

  /// When this suggestion was confirmed (null until confirmed).
  final DateTime? confirmedAt;

  /// When this suggestion was rejected (null until rejected).
  final DateTime? rejectedAt;

  /// When this suggestion was discarded (null until discarded).
  final DateTime? discardedAt;

  /// Filter that caused this suggestion to be flagged (if any).
  final ShotFilterType? filteredBy;

  const ShotDetectionSuggestion({
    required this.id,
    required this.roundId,
    required this.playerId,
    this.clubId,
    this.suggestedLie,
    this.suggestedStartLocation,
    this.suggestedEndLocation,
    required this.confidence,
    required this.level,
    required this.signals,
    required this.reason,
    required this.detectedAt,
    this.status = ShotDetectionSuggestionStatus.pending,
    this.confirmedAt,
    this.rejectedAt,
    this.discardedAt,
    this.filteredBy,
  });

  /// True if this suggestion has been resolved (confirmed, rejected, or discarded).
  bool get isResolved => status != ShotDetectionSuggestionStatus.pending;

  /// True if this suggestion is pending review.
  bool get isPending => status == ShotDetectionSuggestionStatus.pending;

  /// True if this suggestion should be auto-accepted.
  bool get shouldAutoAccept => level == ShotConfidenceLevel.automatic;

  ShotDetectionSuggestion copyWith({
    String? id,
    String? roundId,
    String? playerId,
    String? clubId,
    String? suggestedLie,
    String? suggestedStartLocation,
    String? suggestedEndLocation,
    double? confidence,
    ShotConfidenceLevel? level,
    ShotDetectionSignals? signals,
    String? reason,
    DateTime? detectedAt,
    ShotDetectionSuggestionStatus? status,
    DateTime? confirmedAt,
    DateTime? rejectedAt,
    DateTime? discardedAt,
    ShotFilterType? filteredBy,
    bool clearClubId = false,
    bool clearSuggestedEndLocation = false,
    bool clearFilteredBy = false,
  }) {
    return ShotDetectionSuggestion(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      playerId: playerId ?? this.playerId,
      clubId: clearClubId ? null : (clubId ?? this.clubId),
      suggestedLie: suggestedLie ?? this.suggestedLie,
      suggestedStartLocation:
          suggestedStartLocation ?? this.suggestedStartLocation,
      suggestedEndLocation: clearSuggestedEndLocation
          ? null
          : (suggestedEndLocation ?? this.suggestedEndLocation),
      confidence: confidence ?? this.confidence,
      level: level ?? this.level,
      signals: signals ?? this.signals,
      reason: reason ?? this.reason,
      detectedAt: detectedAt ?? this.detectedAt,
      status: status ?? this.status,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      discardedAt: discardedAt ?? this.discardedAt,
      filteredBy: clearFilteredBy ? null : (filteredBy ?? this.filteredBy),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roundId': roundId,
    'playerId': playerId,
    'clubId': clubId,
    'suggestedLie': suggestedLie,
    'suggestedStartLocation': suggestedStartLocation,
    'suggestedEndLocation': suggestedEndLocation,
    'confidence': confidence,
    'level': level.name,
    'signals': signals.toJson(),
    'reason': reason,
    'detectedAt': detectedAt.toIso8601String(),
    'status': status.name,
    'confirmedAt': confirmedAt?.toIso8601String(),
    'rejectedAt': rejectedAt?.toIso8601String(),
    'discardedAt': discardedAt?.toIso8601String(),
    'filteredBy': filteredBy?.name,
  };

  factory ShotDetectionSuggestion.fromJson(Map<String, dynamic> json) {
    return ShotDetectionSuggestion(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      playerId: json['playerId'] as String,
      clubId: json['clubId'] as String?,
      suggestedLie: json['suggestedLie'] as String?,
      suggestedStartLocation: json['suggestedStartLocation'] as String?,
      suggestedEndLocation: json['suggestedEndLocation'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      level: ShotConfidenceLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => ShotConfidenceLevel.reviewLater,
      ),
      signals: ShotDetectionSignals.fromJson(
        json['signals'] as Map<String, dynamic>,
      ),
      reason: json['reason'] as String,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      status: ShotDetectionSuggestionStatus.fromString(
        json['status'] as String?,
      ),
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.parse(json['confirmedAt'] as String)
          : null,
      rejectedAt: json['rejectedAt'] != null
          ? DateTime.parse(json['rejectedAt'] as String)
          : null,
      discardedAt: json['discardedAt'] != null
          ? DateTime.parse(json['discardedAt'] as String)
          : null,
      filteredBy: json['filteredBy'] != null
          ? ShotFilterType.values.firstWhere(
              (f) => f.name == json['filteredBy'],
              orElse: () => ShotFilterType.practiceSwing,
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    roundId,
    playerId,
    clubId,
    suggestedLie,
    suggestedStartLocation,
    suggestedEndLocation,
    confidence,
    level,
    signals,
    reason,
    detectedAt,
    status,
    confirmedAt,
    rejectedAt,
    discardedAt,
    filteredBy,
  ];
}

// ─── Configuration ──────────────────────────────────────────────────────────

/// Configuration for shot detection thresholds and windows.
///
/// Stored in app config, settable per round mode (casual/practice/tournament).
class ShotDetectionConfig extends Equatable {
  /// Confidence thresholds for level determination.
  final ShotDetectionThresholds thresholds;

  /// Detection window timing parameters.
  final ShotDetectionWindows windows;

  /// Filter-specific parameters.
  final ShotDetectionFilters filters;

  const ShotDetectionConfig({
    this.thresholds = const ShotDetectionThresholds(),
    this.windows = const ShotDetectionWindows(),
    this.filters = const ShotDetectionFilters(),
  });

  ShotConfidenceLevel levelForScore(double score) =>
      thresholds.levelForScore(score);

  /// Default configuration for casual play.
  static const ShotDetectionConfig defaultCasual = ShotDetectionConfig();

  /// Default configuration for practice mode (more lenient).
  static const ShotDetectionConfig defaultPractice = ShotDetectionConfig(
    thresholds: ShotDetectionThresholds(
      automaticMin: 0.70,
      confirmMin: 0.45,
      reviewLaterMin: 0.15,
      discardMax: 0.15,
    ),
    windows: ShotDetectionWindows(
      detectionWindowSeconds: 45,
      minTimeBetweenShots: 20,
      maxShortShotDistanceMeters: 15,
    ),
  );

  /// Default configuration for tournament mode (stricter).
  static const ShotDetectionConfig defaultTournament = ShotDetectionConfig(
    thresholds: ShotDetectionThresholds(
      automaticMin: 0.85,
      confirmMin: 0.60,
      reviewLaterMin: 0.30,
      discardMax: 0.30,
    ),
    windows: ShotDetectionWindows(
      detectionWindowSeconds: 20,
      minTimeBetweenShots: 10,
      maxShortShotDistanceMeters: 5,
    ),
  );

  ShotDetectionConfig copyWith({
    ShotDetectionThresholds? thresholds,
    ShotDetectionWindows? windows,
    ShotDetectionFilters? filters,
  }) {
    return ShotDetectionConfig(
      thresholds: thresholds ?? this.thresholds,
      windows: windows ?? this.windows,
      filters: filters ?? this.filters,
    );
  }

  Map<String, dynamic> toJson() => {
    'thresholds': thresholds.toJson(),
    'windows': windows.toJson(),
    'filters': filters.toJson(),
  };

  factory ShotDetectionConfig.fromJson(Map<String, dynamic> json) {
    return ShotDetectionConfig(
      thresholds: ShotDetectionThresholds.fromJson(
        json['thresholds'] as Map<String, dynamic>? ?? {},
      ),
      windows: ShotDetectionWindows.fromJson(
        json['windows'] as Map<String, dynamic>? ?? {},
      ),
      filters: ShotDetectionFilters.fromJson(
        json['filters'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  @override
  List<Object?> get props => [thresholds, windows, filters];
}

/// Confidence thresholds for shot detection levels.
class ShotDetectionThresholds extends Equatable {
  /// Minimum score for automatic acceptance.
  final double automaticMin;

  /// Minimum score for confirmation suggestion.
  final double confirmMin;

  /// Minimum score for review-later.
  final double reviewLaterMin;

  /// Maximum score for discard (scores below this are discard).
  final double discardMax;

  const ShotDetectionThresholds({
    this.automaticMin = 0.75,
    this.confirmMin = 0.50,
    this.reviewLaterMin = 0.20,
    this.discardMax = 0.20,
  });

  /// Derive confidence level from score using these thresholds.
  ShotConfidenceLevel levelForScore(double score) {
    if (score >= automaticMin) return ShotConfidenceLevel.automatic;
    if (score >= confirmMin) return ShotConfidenceLevel.confirm;
    if (score >= reviewLaterMin) return ShotConfidenceLevel.reviewLater;
    return ShotConfidenceLevel.discard;
  }

  Map<String, dynamic> toJson() => {
    'automaticMin': automaticMin,
    'confirmMin': confirmMin,
    'reviewLaterMin': reviewLaterMin,
    'discardMax': discardMax,
  };

  factory ShotDetectionThresholds.fromJson(Map<String, dynamic> json) {
    return ShotDetectionThresholds(
      automaticMin: (json['automaticMin'] as num?)?.toDouble() ?? 0.75,
      confirmMin: (json['confirmMin'] as num?)?.toDouble() ?? 0.50,
      reviewLaterMin: (json['reviewLaterMin'] as num?)?.toDouble() ?? 0.20,
      discardMax: (json['discardMax'] as num?)?.toDouble() ?? 0.20,
    );
  }

  @override
  List<Object?> get props => [
    automaticMin,
    confirmMin,
    reviewLaterMin,
    discardMax,
  ];
}

/// Detection window timing parameters.
class ShotDetectionWindows extends Equatable {
  /// Duration of each detection window in seconds.
  final int detectionWindowSeconds;

  /// Minimum time between shots in seconds.
  final int minTimeBetweenShots;

  /// Maximum distance in meters for a short shot (putt).
  final double maxShortShotDistanceMeters;

  const ShotDetectionWindows({
    this.detectionWindowSeconds = 30,
    this.minTimeBetweenShots = 15,
    this.maxShortShotDistanceMeters = 10,
  });

  Map<String, dynamic> toJson() => {
    'detectionWindowSeconds': detectionWindowSeconds,
    'minTimeBetweenShots': minTimeBetweenShots,
    'maxShortShotDistanceMeters': maxShortShotDistanceMeters,
  };

  factory ShotDetectionWindows.fromJson(Map<String, dynamic> json) {
    return ShotDetectionWindows(
      detectionWindowSeconds:
          (json['detectionWindowSeconds'] as num?)?.toInt() ?? 30,
      minTimeBetweenShots: (json['minTimeBetweenShots'] as num?)?.toInt() ?? 15,
      maxShortShotDistanceMeters:
          (json['maxShortShotDistanceMeters'] as num?)?.toDouble() ?? 10.0,
    );
  }

  @override
  List<Object?> get props => [
    detectionWindowSeconds,
    minTimeBetweenShots,
    maxShortShotDistanceMeters,
  ];
}

/// Filter-specific parameters for shot detection.
class ShotDetectionFilters extends Equatable {
  /// Maximum speed (m/s) while on cart path to be considered cart movement.
  final double maxCartPathSpeedMs;

  /// Minimum accelerometer delta for a valid practice swing.
  final double minPracticeSwingAccelerationDelta;

  /// Maximum GPS distance (meters) for a nearby golfer detection.
  final double maxNearbyGolferDistanceMeters;

  /// Minimum GPS jump (meters) to be considered a penalty.
  final double minPenaltyJumpMeters;

  const ShotDetectionFilters({
    this.maxCartPathSpeedMs = 4.5,
    this.minPracticeSwingAccelerationDelta = 2.5,
    this.maxNearbyGolferDistanceMeters = 5.0,
    this.minPenaltyJumpMeters = 50.0,
  });

  Map<String, dynamic> toJson() => {
    'maxCartPathSpeedMs': maxCartPathSpeedMs,
    'minPracticeSwingAccelerationDelta': minPracticeSwingAccelerationDelta,
    'maxNearbyGolferDistanceMeters': maxNearbyGolferDistanceMeters,
    'minPenaltyJumpMeters': minPenaltyJumpMeters,
  };

  factory ShotDetectionFilters.fromJson(Map<String, dynamic> json) {
    return ShotDetectionFilters(
      maxCartPathSpeedMs:
          (json['maxCartPathSpeedMs'] as num?)?.toDouble() ?? 4.5,
      minPracticeSwingAccelerationDelta:
          (json['minPracticeSwingAccelerationDelta'] as num?)?.toDouble() ??
          2.5,
      maxNearbyGolferDistanceMeters:
          (json['maxNearbyGolferDistanceMeters'] as num?)?.toDouble() ?? 5.0,
      minPenaltyJumpMeters:
          (json['minPenaltyJumpMeters'] as num?)?.toDouble() ?? 50.0,
    );
  }

  @override
  List<Object?> get props => [
    maxCartPathSpeedMs,
    minPracticeSwingAccelerationDelta,
    maxNearbyGolferDistanceMeters,
    minPenaltyJumpMeters,
  ];
}
