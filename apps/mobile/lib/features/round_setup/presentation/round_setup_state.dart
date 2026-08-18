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

  /// The đường whose package is actually missing.
  ///
  /// A round on Đường A + B checks both, and the one that fails is not always
  /// the first. Offering to download the course the search happened to return
  /// is how a golfer could download a package, come back, and be told again
  /// that the data was not there — because it was a different nine that was
  /// missing.
  final int? missingCourseId;

  /// Every đường this round needs a package for, and whether it has one.
  ///
  /// A paired round needs two packages and this banner could only ever talk
  /// about one at a time. On Long Biên that produced a sequence no golfer can
  /// assemble: download Đường B, see a green "Sẵn sàng ngoại tuyến"; pick
  /// Đường A → Đường B, see a red "Chưa tải dữ liệu Đường A". Both true, and
  /// read one after the other they say the download did not take. Checked
  /// against the phone that reported it: one package on disk, 1352, and no
  /// trace of 1351 ever having been fetched — the app was right and unreadable
  /// at the same time.
  ///
  /// Empty on a round played on one đường, where the single status says it
  /// all.
  final List<SegmentPackage> segments;

  const PackageReadiness({
    required this.status,
    this.reason,
    this.manifestVersion,
    this.expiresAt,
    this.missingCourseId,
    this.segments = const [],
  });

  bool get isReady => status == PackageStatus.valid;
}

/// One đường of a round, and whether its package is on the device.
class SegmentPackage extends Equatable {
  const SegmentPackage({
    required this.courseId,
    required this.name,
    required this.isReady,
  });

  final int courseId;

  /// The đường's own name — "Đường A". Never the club's: a golfer choosing
  /// between two nines of the same club cannot act on the club's name.
  final String name;

  final bool isReady;

  @override
  List<Object?> get props => [courseId, name, isReady];
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

  /// Whether this round should feed the handicap the app computes.
  ///
  /// Null until the golfer touches the switch, which means "decide from the
  /// format" — practice does not count, anything else does. Kept separate
  /// from the format so that moving the switch survives a change of format
  /// only where the golfer actually made a choice.
  final bool? countsTowardHandicapOverride;

  /// What the round will actually be recorded as, switch or no switch.
  bool get countsTowardHandicap =>
      countsTowardHandicapOverride ?? format != RoundFormat.practice;

  /// True when the server publishes an offline package for this course.
  ///
  /// Most courses have none — 900 holes of this country are a par and a
  /// stroke index and nothing else — and telling a golfer their course is
  /// "not downloaded" when there is nothing to download is a warning about
  /// a choice they do not have.
  final bool coursePackageAvailable;

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
    this.coursePackageAvailable = false,
    this.countsTowardHandicapOverride,
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
    // Keyed on the club, not the đường. The two lists come from different
    // queries and pick different courses of the same facility — nearby the
    // closest, the catalogue the longest — so matching on courseId let Long
    // Biên appear in both sections under two of its own đường.
    final near = nearbyCourses.map(_clubKey).toSet();
    return allCourses.where((c) => !near.contains(_clubKey(c))).toList();
  }

  static int _clubKey(NearbyCourseSuggestion c) =>
      c.facilityId ?? -c.courseId;

  /// True if a course is selected.
  bool get hasCourse => courseId != null && courseName != null;

  /// True when there is a round to start: a course and between one and four
  /// players.
  ///
  /// The offline package is deliberately not part of this. Scoring needs a
  /// par and a hole list, both of which the round already has; the package
  /// buys a map that works without signal. Requiring an acknowledgement of
  /// its absence put a tap between the golfer and the first tee — and did it
  /// on every course that has no package to acknowledge, which is most of
  /// them.
  bool get canStartRound =>
      hasCourse && players.isNotEmpty && players.length <= 4;

  /// True when the banner has something worth saying: a package exists to
  /// download, or one is already here and is stale or broken.
  bool get showsPackageBanner {
    final status = packageReadiness?.status;
    if (status == null) return false;
    if (status == PackageStatus.notDownloaded) return coursePackageAvailable;
    return true;
  }

  /// True if Start Round CTA should be enabled.
  bool get isStartEnabled =>
      canStartRound && validationErrors.isEmpty && !isSubmitting;

  /// Suggested start hole based on time of day.
  /// Hole 1 if before noon, hole 10 if noon or after.
  static int suggestedStartHole() {
    final hour = DateTime.now().hour;
    return hour < 12 ? 1 : 10;
  }

  /// The start hole this round can actually begin on.
  ///
  /// [suggestedStartHole] offers the tenth after midday, which is right for an
  /// eighteen and nonsense for a nine: a round of Đường B started at 13:44
  /// opened on hole 10, and hole 10 does not exist there. The scorecard read
  /// its own hole list and showed 1 of 9 while the map, which takes the start
  /// hole, sat on a hole with no green, no geometry and satellite imagery over
  /// the golfer's own street.
  ///
  /// So the suggestion is clamped to the holes in play, and the golfer's own
  /// choice with it — a round cannot start on a hole it does not contain.
  int get effectiveStartHole {
    final holes = holeNumbersInPlay;
    if (holes.isEmpty) return startHole;
    if (holes.contains(startHole)) return startHole;
    return holes.first;
  }


  /// The course the download button should fetch a package for.
  ///
  /// The đường the readiness check found wanting, where it named one, and the
  /// selected course otherwise. Not `courseId` alone: picking a club leaves
  /// that on whichever đường the search returned, so on a round of A+B where B
  /// is the one missing its package, the button downloaded A — which was
  /// already on the phone — and the banner was still there afterwards saying
  /// the data had not been downloaded.
  int? get packageDownloadCourseId =>
      packageReadiness?.missingCourseId ?? courseId;

  /// What to call that course on the button and in the banner.
  ///
  /// The đường's own name — "Đường B" — and not the club's, which is what the
  /// screen used to pass. A round of A+B needs two packages and the readiness
  /// check reports them one at a time, so a golfer downloads "Long Biên Golf
  /// Course", is told it succeeded, comes back and is told to download "Long
  /// Biên Golf Course". Both sentences are true and the second one is
  /// unreadable: nothing on screen says the first download worked and this is
  /// the other nine.
  ///
  /// Null on a round played on one course, which is most of them: there is
  /// nothing to disambiguate there, and "Chưa tải dữ liệu Long Biên Golf
  /// Course" is a worse sentence than "Chưa tải dữ liệu sân".
  String? get packageDownloadCourseName {
    if (segmentCourseIds.length < 2) return null;
    final id = packageDownloadCourseId;
    if (id == null) return null;
    for (final layout in layouts) {
      if (layout.id == id) return layout.name;
    }
    return null;
  }

  /// Every other đường of this club, so one download covers the sân.
  ///
  /// A package is per-nine and a club is several of them, so downloading only
  /// the nine that was asked for left a golfer changing the pairing and being
  /// sent back to download again — three times over, on a club with three
  /// nines. They are about 8 KB each; rationing them bought nothing and cost
  /// the whole screen its credibility.
  List<int> otherLayoutIds(int downloading) => [
    for (final layout in layouts)
      if (layout.id != downloading) layout.id,
  ];

  /// The đường's own name for an id, or null where the club has no layouts.
  String? layoutNameFor(int id) {
    for (final layout in layouts) {
      if (layout.id == id) return layout.name;
    }
    return null;
  }

  /// What "Sẵn sàng ngoại tuyến" is actually about.
  ///
  /// The missing side of this banner has named its đường since the two-package
  /// round was fixed. The ready side never did, and that asymmetry is its own
  /// bug: a golfer on Long Biên — three đường, six pairings — downloads Đường
  /// B, is told "Sẵn sàng ngoại tuyến" with no subject, then picks A → B and
  /// is told "Chưa tải dữ liệu Đường A". Both sentences are true. Read one
  /// after the other they say the download did not stick, because the first
  /// one never said what it covered.
  ///
  /// Null where the club has a single layout: there is nothing to confuse it
  /// with, and naming it is noise.
  String? get readyCourseNames {
    if (layouts.length < 2) return null;
    final names = <String>[];
    for (final id in segmentCourseIds) {
      for (final layout in layouts) {
        if (layout.id == id) {
          names.add(layout.name);
          break;
        }
      }
    }
    return names.isEmpty ? null : names.join(' + ');
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

  /// The holes this round actually plays, in order.
  ///
  /// From the option the golfer chose. This used to be derived from [holes]
  /// alone — front9, back9, or a default eighteen — which knows nothing about
  /// which đường was picked, so choosing Đường B on its own produced a round
  /// of holes 1 to 18. Holes 10 to 18 do not exist on a nine-hole đường: the
  /// map had no geometry for them, the green had no position, and the screen
  /// fell back to satellite imagery over wherever the golfer was standing.
  ///
  /// [holes] still wins where it is set, because front9/back9 is an explicit
  /// choice about an eighteen rather than a guess.
  List<int> get holeNumbersInPlay {
    switch (holes) {
      case 'front9':
        return [for (var h = 1; h <= 9; h++) h];
      case 'back9':
        return [for (var h = 10; h <= 18; h++) h];
    }
    final count = selectedPlayOption?.holeCount ?? 18;
    return [for (var h = 1; h <= count; h++) h];
  }

  /// The course a round started now would be recorded against.
  ///
  /// The đường, not the club. Selecting Long Biên sets [courseId] to whichever
  /// of its đường the search returned; choosing another afterwards only moves
  /// [selectedLayoutId], and a round that reads [courseId] opens on the wrong
  /// nine with every hole wrong behind it.
  int? get playingCourseId => selectedLayoutId ?? courseId;

  /// True when the chosen đường is a nine and needs a partner to make a round.
  /// Every way this club can actually be played, worked out in advance.
  ///
  /// A club with three nines does not present a golfer with "pick a đường,
  /// then pick another": it presents four or ten real rounds, and the golfer
  /// picks the one they booked. Two dropdowns made them assemble it, and let
  /// them assemble things that are not rounds.
  ///
  /// Eighteens first, then the pairings in playing order, then the nines on
  /// their own. Order matters in a pairing — A then C numbers the holes
  /// differently from C then A — so both directions are offered.
  List<PlayOption> get playOptions {
    final eighteens = layouts.where((l) => l.holeCount >= 18).toList();
    final nines = layouts.where((l) => l.holeCount < 18).toList();
    final options = <PlayOption>[];

    for (final l in eighteens) {
      options.add(PlayOption(first: l, holeCount: l.holeCount));
    }
    for (final a in nines) {
      for (final b in nines) {
        if (a.id == b.id) continue;
        options.add(PlayOption(
          first: a,
          second: b,
          holeCount: a.holeCount + b.holeCount,
        ));
      }
    }
    for (final l in nines) {
      options.add(PlayOption(first: l, holeCount: l.holeCount));
    }
    return options;
  }

  /// The option the form is currently on, or null before a choice.
  PlayOption? get selectedPlayOption {
    for (final option in playOptions) {
      if (option.first.id == selectedLayoutId &&
          option.second?.id == selectedSecondLayoutId) {
        return option;
      }
    }
    return null;
  }

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
    bool? coursePackageAvailable,
    bool? countsTowardHandicapOverride,
    bool clearCountsOverride = false,
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
      coursePackageAvailable:
          coursePackageAvailable ?? this.coursePackageAvailable,
      countsTowardHandicapOverride: clearCountsOverride
          ? null
          : countsTowardHandicapOverride ?? this.countsTowardHandicapOverride,
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
    coursePackageAvailable,
    countsTowardHandicapOverride,
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
/// One playable round at this club: an eighteen, a pairing of nines in the
/// order they are played, or a single nine.
class PlayOption extends Equatable {
  const PlayOption({
    required this.first,
    this.second,
    required this.holeCount,
  });

  final LayoutOption first;

  /// The second nine, where the round is a pairing.
  final LayoutOption? second;

  final int holeCount;

  bool get isPairing => second != null;

  /// "Đường A → Đường C", or just the layout's name.
  String get name =>
      second == null ? first.name : '${first.name} → ${second!.name}';

  @override
  List<Object?> get props => [first, second, holeCount];
}

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
