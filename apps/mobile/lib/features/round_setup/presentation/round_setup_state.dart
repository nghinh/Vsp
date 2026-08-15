// Round Setup State — VSP Mobile App
//
// State classes for RoundSetupBloc covering all selection states,
// package status, validation errors, and round start result.
//
// Story 5.1 — Slice C: Round Setup BLoC

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

import '../../../domain/models/round_format.dart';
import '../../../domain/models/round_mode.dart';
import '../../../domain/models/player.dart';
import 'round_setup_event.dart';

/// Package readiness status.
enum PackageStatus {
  /// Not yet checked.
  notChecked,

  /// Package is ready for offline play.
  valid,

  /// Package is invalid (checksum mismatch).
  invalid,

  /// Package has expired.
  expired,

  /// Package not downloaded for this course.
  notDownloaded,
}

/// Package readiness result with reason.
class PackageReadiness {
  final PackageStatus status;
  final String? reason;
  final String? manifestVersion;
  final DateTime? expiresAt;

  const PackageReadiness({
    required this.status,
    this.reason,
    this.manifestVersion,
    this.expiresAt,
  });

  bool get isReady => status == PackageStatus.valid;
}

/// Base state for round setup.
class RoundSetupState extends Equatable {
  const RoundSetupState();

  @override
  List<Object?> get props => [];
}

// ─── Initial State ────────────────────────────────────────────────────────────

/// Initial state — loading primary player and active bag.
class RoundSetupInitial extends RoundSetupState {
  const RoundSetupInitial();
}

// ─── Loading State ─────────────────────────────────────────────────────────────

/// Loading data (initial load or course lookup).
class RoundSetupLoading extends RoundSetupState {
  const RoundSetupLoading();
}

// ─── Ready State (main working state) ────────────────────────────────────────

/// Main working state with all selections.
class RoundSetupReady extends RoundSetupState {
  // Course
  final int? courseId;
  final String? courseName;
  final String? packageId;

  // Course layouts (populated after course selected)
  final List<LayoutOption> layouts;
  final int? selectedLayoutId;

  /// The second đường, when the first is a nine and the golfer pairs it.
  final int? selectedSecondLayoutId;

  // Tee sets (populated after course selected)
  final List<TeeOption> tees;
  final int? selectedTeeId;

  // Players
  final List<Player> players; // 1-4 players
  final Player? primaryPlayer; // self from profile

  // Format / Mode
  final RoundFormat format;
  final RoundMode mode;

  // Bag
  final int? selectedBagId;
  final BagOption? activeBag;

  // Start hole
  final int startHole;
  final String? holes; // 'front9' or 'back9'

  // Package status
  final PackageReadiness? packageReadiness;
  final bool warningAcknowledged;

  // Tournament policy
  final String? tournamentPolicyId;

  /// Courses within reach of the golfer's current position, nearest first.
  ///
  /// Genuinely nearby: these come from a GPS fix and the server's ST_DWithin
  /// query, and each carries the distance it is away. Empty where there is no
  /// fix, no permission, or nothing within the radius — all of which are
  /// ordinary, and none of which stops the picker working.
  final List<NearbyCourseSuggestion> nearbyCourses;

  /// The catalogue, alphabetically. What the picker falls back to, and what
  /// it showed under a "nearby" heading before any of it was near anything.
  final List<NearbyCourseSuggestion> allCourses;

  final List<RecentCourseSuggestion> recentCourses;

  // Validation
  final List<String> validationErrors;

  /// Real par per hole number, from the course detail API. Used to seed the
  /// scorecard so score entry is scored against the actual course.
  final Map<int, int> holePars;

  // Submitting
  final bool isSubmitting;

  const RoundSetupReady({
    this.courseId,
    this.courseName,
    this.packageId,
    this.layouts = const [],
    this.selectedLayoutId,
    this.selectedSecondLayoutId,
    this.tees = const [],
    this.selectedTeeId,
    this.players = const [],
    this.primaryPlayer,
    this.format = RoundFormat.casual,
    this.mode = RoundMode.strokePlay,
    this.selectedBagId,
    this.activeBag,
    this.startHole = 1,
    this.holes,
    this.packageReadiness,
    this.warningAcknowledged = false,
    this.tournamentPolicyId,
    this.nearbyCourses = const [],
    this.allCourses = const [],
    this.recentCourses = const [],
    this.validationErrors = const [],
    this.holePars = const {},
    this.isSubmitting = false,
  });

  /// The catalogue, minus every course already listed as nearby.
  ///
  /// The picker draws nearby first and the catalogue under it. A club in both
  /// lists appears twice — once with a distance, once without — which reads
  /// as two different places rather than one listed twice.
  List<NearbyCourseSuggestion> get catalogueBeyondNearby {
    final near = nearbyCourses.map((c) => c.courseId).toSet();
    return allCourses.where((c) => !near.contains(c.courseId)).toList();
  }

  /// True if a course is selected.
  bool get hasCourse => courseId != null && courseName != null;

  /// True if a valid package is ready (or warning was acknowledged).
  bool get canStartRound =>
      hasCourse &&
      players.isNotEmpty &&
      players.length <= 4 &&
      (packageReadiness?.isReady == true || warningAcknowledged);

  /// True if Start Round CTA should be enabled.
  bool get isStartEnabled =>
      canStartRound && validationErrors.isEmpty && !isSubmitting;

  /// Suggested start hole based on time of day.
  /// Hole 1 if before noon, hole 10 if noon or after.
  static int suggestedStartHole() {
    final hour = DateTime.now().hour;
    return hour < 12 ? 1 : 10;
  }


  /// The đường the round is played on, in playing order.
  ///
  /// One id for a round on a full eighteen. Two when the golfer paired nines —
  /// Long Biên's A+C — and that pairing exists nowhere else: the round's own
  /// courseId can hold no more than the first of them.
  List<int> get segmentCourseIds => [
    if (selectedLayoutId != null) selectedLayoutId! else if (courseId != null) courseId!,
    if (selectedSecondLayoutId != null) selectedSecondLayoutId!,
  ];

  /// True when the chosen đường is a nine and needs a partner to make a round.
  bool get needsSecondLayout {
    final first = layouts.where((l) => l.id == selectedLayoutId);
    return first.isNotEmpty && first.first.holeCount < 18 && layouts.length > 1;
  }

  RoundSetupReady copyWith({
    int? courseId,
    String? courseName,
    String? packageId,
    List<LayoutOption>? layouts,
    int? selectedLayoutId,
    int? selectedSecondLayoutId,
    bool clearSecondLayout = false,
    List<TeeOption>? tees,
    int? selectedTeeId,
    List<Player>? players,
    Player? primaryPlayer,
    RoundFormat? format,
    RoundMode? mode,
    int? selectedBagId,
    BagOption? activeBag,
    int? startHole,
    String? holes,
    PackageReadiness? packageReadiness,
    bool? warningAcknowledged,
    String? tournamentPolicyId,
    List<NearbyCourseSuggestion>? nearbyCourses,
    List<NearbyCourseSuggestion>? allCourses,
    List<RecentCourseSuggestion>? recentCourses,
    List<String>? validationErrors,
    Map<int, int>? holePars,
    bool? isSubmitting,
  }) {
    return RoundSetupReady(
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      packageId: packageId ?? this.packageId,
      layouts: layouts ?? this.layouts,
      selectedLayoutId: selectedLayoutId ?? this.selectedLayoutId,
      selectedSecondLayoutId: clearSecondLayout
          ? null
          : (selectedSecondLayoutId ?? this.selectedSecondLayoutId),
      tees: tees ?? this.tees,
      selectedTeeId: selectedTeeId ?? this.selectedTeeId,
      players: players ?? this.players,
      primaryPlayer: primaryPlayer ?? this.primaryPlayer,
      format: format ?? this.format,
      mode: mode ?? this.mode,
      selectedBagId: selectedBagId ?? this.selectedBagId,
      activeBag: activeBag ?? this.activeBag,
      startHole: startHole ?? this.startHole,
      holes: holes ?? this.holes,
      packageReadiness: packageReadiness ?? this.packageReadiness,
      warningAcknowledged: warningAcknowledged ?? this.warningAcknowledged,
      tournamentPolicyId: tournamentPolicyId ?? this.tournamentPolicyId,
      nearbyCourses: nearbyCourses ?? this.nearbyCourses,
      allCourses: allCourses ?? this.allCourses,
      recentCourses: recentCourses ?? this.recentCourses,
      validationErrors: validationErrors ?? this.validationErrors,
      holePars: holePars ?? this.holePars,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [
    courseId,
    courseName,
    packageId,
    layouts,
    selectedLayoutId,
    selectedSecondLayoutId,
    tees,
    selectedTeeId,
    players,
    primaryPlayer,
    format,
    mode,
    selectedBagId,
    activeBag,
    startHole,
    holes,
    packageReadiness,
    warningAcknowledged,
    tournamentPolicyId,
    nearbyCourses,
    allCourses,
    recentCourses,
    validationErrors,
    holePars,
    isSubmitting,
  ];
}

/// Layout option from course manifest.
class LayoutOption extends Equatable {
  final int id;
  final String name;
  final int holeCount;

  const LayoutOption({
    required this.id,
    required this.name,
    required this.holeCount,
  });

  @override
  List<Object?> get props => [id, name, holeCount];
}

/// Tee option from course manifest.
class TeeOption extends Equatable {
  final int id;
  final String name;
  final String? gender;
  final double? courseRating;
  final double? slopeRating;

  /// What the whole course measures from this tee, or null when the club has
  /// published no card and the yardages with it.
  ///
  /// The name on its own does not decide anything. GOLD and WHITE at Sky Lake
  /// are 7,313 and 6,119 — a different golf course, and the number is the
  /// reason a golfer picks one.
  final int? totalDistance;

  const TeeOption({
    required this.id,
    required this.name,
    this.gender,
    this.courseRating,
    this.slopeRating,
    this.totalDistance,
  });

  @override
  List<Object?> get props =>
      [id, name, gender, courseRating, slopeRating, totalDistance];
}

/// "GOLD · 6.688 m · 74.1/141" — as much of it as the club published.
///
/// Lives here rather than in the screen so it can be tested without building
/// a widget: what this string says is the whole of the tee decision.
///
/// [unit] is the golfer's own, and [TeeOption.totalDistance] is metres — named
/// yardage the whole way down from the OpenAPI contract, whose own description
/// says metres. Suffixing it `y` did not overstate the number, it mislabelled
/// it: a 6.000 m course was printed as "6.000y", which is a different course.
String teeLabel(TeeOption t, DistanceUnit unit) {
  final parts = <String>[t.name];
  if (t.totalDistance != null) {
    parts.add('${_grouped(MeasureUnits.displayValue(
      t.totalDistance!.toDouble(),
      unit,
    ))} ${MeasureUnits.suffix(unit)}');
  }
  if (t.courseRating != null && t.slopeRating != null) {
    parts.add('${t.courseRating}/${t.slopeRating!.toInt()}');
  }
  return parts.join(' · ');
}

String _grouped(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );

/// Bag option for selection.
class BagOption extends Equatable {
  final int id;
  final String name;
  final bool isActive;

  const BagOption({
    required this.id,
    required this.name,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, name, isActive];
}

// ─── Round Start Result States ────────────────────────────────────────────────

/// Round created and guard recorded — navigate to active round.
class RoundSetupRoundStarted extends RoundSetupState {
  /// Server-assigned round id (UUID). Falls back to the local id when the
  /// round was created offline.
  final String roundId;
  final int courseId;
  final String courseName;

  const RoundSetupRoundStarted({
    required this.roundId,
    required this.courseId,
    required this.courseName,
  });

  @override
  List<Object?> get props => [roundId, courseId, courseName];
}

/// Round saved locally (offline) — navigate to active round with sync badge.
class RoundSetupLocalRoundSaved extends RoundSetupState {
  final int courseId;
  final String courseName;
  final String localRoundId;

  const RoundSetupLocalRoundSaved({
    required this.courseId,
    required this.courseName,
    required this.localRoundId,
  });

  @override
  List<Object?> get props => [courseId, courseName, localRoundId];
}

// ─── Error State ─────────────────────────────────────────────────────────────

/// Error state.
class RoundSetupError extends RoundSetupState {
  final String message;
  final RoundSetupReady? lastState;

  const RoundSetupError({required this.message, this.lastState});

  @override
  List<Object?> get props => [message, lastState];
}
