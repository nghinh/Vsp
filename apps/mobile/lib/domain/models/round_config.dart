// Round Config Model — VSP Mobile App
//
// Domain model for round configuration: course, layout, tee, format, players,
// mode, bag, start hole, and start time.
//
// Story 5.1 — Slice A: Domain Models

import 'package:equatable/equatable.dart';

import 'course_package_manifest.dart';
import 'player.dart';
import 'round_format.dart';
import 'round_mode.dart';

/// Validation error for round configuration.
class RoundConfigValidationError {
  final String field;
  final String message;

  const RoundConfigValidationError(this.field, this.message);

  @override
  String toString() => 'RoundConfigValidationError($field: $message)';
}

/// Result of validating a [RoundConfig].
class RoundConfigValidationResult {
  final bool isValid;
  final List<RoundConfigValidationError> errors;

  const RoundConfigValidationResult({
    required this.isValid,
    this.errors = const [],
  });

  factory RoundConfigValidationResult.valid() =>
      const RoundConfigValidationResult(isValid: true);

  factory RoundConfigValidationResult.invalid(
    List<RoundConfigValidationError> errors,
  ) => RoundConfigValidationResult(isValid: false, errors: errors);

  /// True if the given [hole] number is a valid starting hole (1–18 or 1–9 front/10–18 back).
  static bool isValidStartHole(int hole) => hole >= 1 && hole <= 18;

  /// True if the given [holes] string represents a valid front-9 or back-9 selection.
  /// Valid values: 'front9', 'back9'.
  static bool isValidHoleSelection(String? holes) {
    if (holes == null) return true;
    return holes == 'front9' || holes == 'back9';
  }
}

/// Domain model for round configuration.
///
/// Used to capture all parameters needed to start a round before
/// persisting locally and calling the backend API.
///
/// Validation rules:
/// - 1 ≤ players.length ≤ 4
/// - startHole 1–18 (single hole) or holes = 'front9'|'back9' (9-hole start)
/// - courseId > 0
/// - format and mode are non-null
/// - startTime is non-null and not in the past
class RoundConfig extends Equatable {
  /// Unique course identifier.
  final int courseId;

  /// Display name of the selected course (for offline display).
  final String courseName;

  /// Layout identifier within the course (optional — null means default).
  final int? layoutId;

  /// Tee set identifier (from course package manifest).
  final int? teeId;

  /// Round format (casual, practice, tournament).
  final RoundFormat format;

  /// Player IDs participating in this round (1–4 players).
  /// The first ID is always the primary (self).
  final List<String> playerIds;

  /// Resolved [Player] objects for the [playerIds].
  /// Populated by the BLoC after fetching player details.
  final List<Player> players;

  /// Scoring mode (strokePlay MVP; stableford locked in MVP).
  final RoundMode mode;

  /// Active bag identifier used for club recommendations.
  final int? bagId;

  /// Starting hole number (1–18).
  /// Use holes='front9' or holes='back9' for 9-hole starts.
  final int startHole;

  /// 9-hole start selection: 'front9' or 'back9' (null for 18-hole).
  final String? holes;

  /// Scheduled or actual start time of the round.
  final DateTime startTime;

  /// Associated offline package identifier for this course.
  /// Populated from the active [CoursePackageManifest].
  final String? packageId;

  /// Tournament policy ID for tournament-format rounds.
  /// Required when [format] is [RoundFormat.tournament].
  /// Null for casual and practice rounds (no feature restrictions apply).
  final String? tournamentPolicyId;

  const RoundConfig({
    required this.courseId,
    required this.courseName,
    this.layoutId,
    this.teeId,
    required this.format,
    required this.playerIds,
    this.players = const [],
    this.mode = RoundMode.strokePlay,
    this.bagId,
    required this.startHole,
    this.holes,
    required this.startTime,
    this.packageId,
    this.tournamentPolicyId,
  });

  // -------------------------------------------------------------------------
  // Validation
  // -------------------------------------------------------------------------

  /// Validates this round configuration and returns the result.
  ///
  /// Returns [RoundConfigValidationResult.valid] if all rules pass,
  /// or [RoundConfigValidationResult.invalid] with a list of errors.
  RoundConfigValidationResult validate() {
    final errors = <RoundConfigValidationError>[];

    if (courseId <= 0) {
      errors.add(
        const RoundConfigValidationError('courseId', 'Course must be selected'),
      );
    }

    if (playerIds.isEmpty || playerIds.length > 4) {
      errors.add(
        const RoundConfigValidationError(
          'playerIds',
          'Round requires 1 to 4 players',
        ),
      );
    }

    if (!RoundConfigValidationResult.isValidStartHole(startHole)) {
      errors.add(
        const RoundConfigValidationError(
          'startHole',
          'Starting hole must be between 1 and 18',
        ),
      );
    }

    if (!RoundConfigValidationResult.isValidHoleSelection(holes)) {
      errors.add(
        const RoundConfigValidationError(
          'holes',
          'Hole selection must be front9 or back9',
        ),
      );
    }

    // format is non-nullable with default — no null check needed.

    if (format == RoundFormat.tournament && tournamentPolicyId == null) {
      errors.add(
        const RoundConfigValidationError(
          'tournamentPolicyId',
          'Tournament rounds require a tournament policy ID',
        ),
      );
    }

    // Allow a small grace period: an immediate round sets startTime = now(),
    // and the few milliseconds elapsed before this check must not make it
    // "in the past". Genuinely past/scheduled times are still rejected.
    if (startTime.isBefore(
      DateTime.now().subtract(const Duration(minutes: 1)),
    )) {
      errors.add(
        const RoundConfigValidationError(
          'startTime',
          'Start time cannot be in the past',
        ),
      );
    }

    return errors.isEmpty
        ? RoundConfigValidationResult.valid()
        : RoundConfigValidationResult.invalid(errors);
  }

  /// Convenience getter: true if this config is valid.
  bool get isValid => validate().isValid;

  // -------------------------------------------------------------------------
  // Offline readiness
  // -------------------------------------------------------------------------

  /// Returns true when the offline package for this course is ready.
  ///
  /// Requires:
  /// - [packageId] is non-null and non-empty
  /// - [manifest] is non-null
  /// - [manifest.isEffective] is true
  ///
  /// Callers should pass the active [CoursePackageManifest] retrieved
  /// from [PackageManifestRepository.getActiveManifest].
  bool isOfflineReady(CoursePackageManifest? manifest) {
    if (packageId == null || packageId!.isEmpty) return false;
    if (manifest == null) return false;
    return manifest.isEffective;
  }

  // -------------------------------------------------------------------------
  // JSON
  // -------------------------------------------------------------------------

  factory RoundConfig.fromJson(Map<String, dynamic> json) {
    return RoundConfig(
      courseId: int.parse(json['courseId'].toString().split('/').last),
      courseName: json['courseName'] as String,
      layoutId: json['layoutId'] != null
          ? int.parse(json['layoutId'].toString().split('/').last)
          : null,
      teeId: json['teeId'] != null
          ? int.parse(json['teeId'].toString().split('/').last)
          : null,
      format: RoundFormat.fromString(json['format'] as String),
      playerIds: (json['playerIds'] as List<dynamic>? ?? const []).cast<String>(),
      players:
          (json['players'] as List<dynamic>?)
              ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mode: RoundMode.fromString(json['mode'] as String? ?? 'STROKE_PLAY'),
      bagId: json['bagId'] != null
          ? int.parse(json['bagId'].toString().split('/').last)
          : null,
      startHole: (json['startHole'] as num?)?.toInt() ?? 1,
      holes: json['holes'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      packageId: json['packageId'] as String?,
      tournamentPolicyId: json['tournamentPolicyId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'courseName': courseName,
    if (layoutId != null) 'layoutId': layoutId,
    if (teeId != null) 'teeId': teeId,
    'format': format.value,
    'playerIds': playerIds,
    'players': players.map((p) => p.toJson()).toList(),
    'mode': mode.value,
    if (bagId != null) 'bagId': bagId,
    'startHole': startHole,
    if (holes != null) 'holes': holes,
    'startTime': startTime.toIso8601String(),
    if (packageId != null) 'packageId': packageId,
    if (tournamentPolicyId != null) 'tournamentPolicyId': tournamentPolicyId,
  };

  // -------------------------------------------------------------------------
  // Copy
  // -------------------------------------------------------------------------

  RoundConfig copyWith({
    int? courseId,
    String? courseName,
    int? layoutId,
    int? teeId,
    RoundFormat? format,
    List<String>? playerIds,
    List<Player>? players,
    RoundMode? mode,
    int? bagId,
    int? startHole,
    String? holes,
    DateTime? startTime,
    String? packageId,
    String? tournamentPolicyId,
  }) {
    return RoundConfig(
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      layoutId: layoutId ?? this.layoutId,
      teeId: teeId ?? this.teeId,
      format: format ?? this.format,
      playerIds: playerIds ?? this.playerIds,
      players: players ?? this.players,
      mode: mode ?? this.mode,
      bagId: bagId ?? this.bagId,
      startHole: startHole ?? this.startHole,
      holes: holes ?? this.holes,
      startTime: startTime ?? this.startTime,
      packageId: packageId ?? this.packageId,
      tournamentPolicyId: tournamentPolicyId ?? this.tournamentPolicyId,
    );
  }

  @override
  List<Object?> get props => [
    courseId,
    courseName,
    layoutId,
    teeId,
    format,
    playerIds,
    players,
    mode,
    bagId,
    startHole,
    holes,
    startTime,
    packageId,
    tournamentPolicyId,
  ];
}
