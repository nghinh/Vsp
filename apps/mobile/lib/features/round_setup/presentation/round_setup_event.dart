// Round Setup Events — VSP Mobile App
//
// Events for RoundSetupBloc covering course/player/format/mode/bag/startHole
// selection and round start trigger.
//
// Story 5.1 — Slice C: Round Setup BLoC

import 'package:vsp_mobile/core/text/vietnamese_search.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/models/round_format.dart';
import '../../../domain/models/round_mode.dart';
import '../../../domain/models/player.dart';

/// Base event for round setup.
abstract class RoundSetupEvent extends Equatable {
  const RoundSetupEvent();

  @override
  List<Object?> get props => [];
}

// ─── Course Selection ─────────────────────────────────────────────────────────

/// Course was selected (from search or nearby suggestion).
class CourseSelected extends RoundSetupEvent {
  final int courseId;
  final String courseName;
  final String? packageId;

  const CourseSelected({
    required this.courseId,
    required this.courseName,
    this.packageId,
  });

  @override
  List<Object?> get props => [courseId, courseName, packageId];
}

/// Layout was selected from course layouts.
class LayoutSelected extends RoundSetupEvent {
  final int layoutId;

  const LayoutSelected(this.layoutId);

  @override
  List<Object?> get props => [layoutId];
}

/// The second đường of a paired round was selected.
class SecondLayoutSelected extends RoundSetupEvent {
  final int? layoutId;

  const SecondLayoutSelected(this.layoutId);

  @override
  List<Object?> get props => [layoutId];
}

/// Tee set was selected.
class TeeSelected extends RoundSetupEvent {
  final int teeId;

  const TeeSelected(this.teeId);

  @override
  List<Object?> get props => [teeId];
}

// ─── Player Management ───────────────────────────────────────────────────────

/// Add a player to the round (up to 4 total).
class PlayerAdded extends RoundSetupEvent {
  final Player player;

  const PlayerAdded(this.player);

  @override
  List<Object?> get props => [player];
}

/// Remove a player from the round.
class PlayerRemoved extends RoundSetupEvent {
  final String playerId;

  const PlayerRemoved(this.playerId);

  @override
  List<Object?> get props => [playerId];
}

// ─── Format / Mode Selection ─────────────────────────────────────────────────

/// Round format changed (casual/practice/tournament).
class FormatChanged extends RoundSetupEvent {
  final RoundFormat format;

  const FormatChanged(this.format);

  @override
  List<Object?> get props => [format];
}

/// Scoring mode changed (strokePlay/stableford).
class ModeChanged extends RoundSetupEvent {
  final RoundMode mode;

  const ModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}

// ─── Bag Selection ───────────────────────────────────────────────────────────

/// Active bag changed.
class BagChanged extends RoundSetupEvent {
  final int bagId;

  const BagChanged(this.bagId);

  @override
  List<Object?> get props => [bagId];
}

// ─── Start Hole ──────────────────────────────────────────────────────────────

/// Starting hole changed.
class StartHoleChanged extends RoundSetupEvent {
  final int hole;
  final String? holes; // 'front9' or 'back9' for 9-hole start

  const StartHoleChanged(this.hole, {this.holes});

  @override
  List<Object?> get props => [hole, holes];
}

// ─── Package Validation ───────────────────────────────────────────────────────

/// Request package readiness validation for the selected course.
class PackageValidationRequested extends RoundSetupEvent {
  const PackageValidationRequested();
}

/// User acknowledged package warning and wants to proceed anyway.
class PackageWarningAcknowledged extends RoundSetupEvent {
  const PackageWarningAcknowledged();
}

// ─── Round Start ─────────────────────────────────────────────────────────────

/// Start Round button was tapped.
class StartRoundTapped extends RoundSetupEvent {
  const StartRoundTapped();
}

// ─── Tournament Policy ──────────────────────────────────────────────────────

/// Tournament policy was loaded for a tournament-format round.
class TournamentPolicySelected extends RoundSetupEvent {
  /// The tournament policy ID to attach to the round.
  final String policyId;

  const TournamentPolicySelected(this.policyId);

  @override
  List<Object?> get props => [policyId];
}

// ─── Nearby / GPS ────────────────────────────────────────────────────────────

/// Nearby courses loaded from GPS location.
class NearbyCoursesLoaded extends RoundSetupEvent {
  final List<NearbyCourseSuggestion> courses;

  const NearbyCoursesLoaded(this.courses);

  @override
  List<Object?> get props => [courses];
}

/// Last-played courses loaded as fallback.
class LastPlayedCoursesLoaded extends RoundSetupEvent {
  final List<RecentCourseSuggestion> courses;

  const LastPlayedCoursesLoaded(this.courses);

  @override
  List<Object?> get props => [courses];
}

/// Nearby course suggestion model.
class NearbyCourseSuggestion extends Equatable {
  final int courseId;

  /// The name of the đường — "Đường A", "Kings Course". Useful as a subtitle
  /// and useless as a title: nobody searches for it, and on its own it does
  /// not say which club it belongs to.
  final String courseName;

  /// The club. What a golfer types, and what the picker shows.
  final int? facilityId;
  final String? facilityName;

  /// Null where the facility has no established location. The picker shows
  /// the course either way — a golfer who knows the name should be able to
  /// start a round on it — and simply has no distance to offer.
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? packageId;

  const NearbyCourseSuggestion({
    required this.courseId,
    required this.courseName,
    this.facilityId,
    this.facilityName,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.packageId,
  });

  /// What the picker draws and matches against: the club where there is
  /// one, the đường only as a fallback.
  String get displayName =>
      facilityName?.isNotEmpty == true ? facilityName! : courseName;

  /// Whether this row answers what the golfer typed.
  ///
  /// The club and the đường both. Filtering on the đường alone is what made
  /// "long" miss Long Biên — its đường are named A, B and C — while finding
  /// FLC Hạ Long, whose đường carries the club's name.
  bool matchesQuery(String query) =>
      VietnameseSearch.matches(displayName, query) ||
      VietnameseSearch.matches(courseName, query);

  /// The đường, when it says something the club name does not.
  String? get subtitleName {
    if (facilityName == null || facilityName!.isEmpty) return null;
    if (courseName.isEmpty || courseName == facilityName) return null;
    // "Long Biên Golf Course — Championship" under "Long Biên Golf Course"
    // is the same name twice.
    if (courseName.startsWith(facilityName!)) return null;
    return courseName;
  }

  @override
  List<Object?> get props => [
    courseId,
    courseName,
    facilityId,
    facilityName,
    latitude,
    longitude,
    distanceKm,
    packageId,
  ];
}

/// Recent course suggestion model.
class RecentCourseSuggestion extends Equatable {
  final int courseId;
  final String courseName;
  final DateTime lastPlayedAt;
  final String? packageId;

  const RecentCourseSuggestion({
    required this.courseId,
    required this.courseName,
    required this.lastPlayedAt,
    this.packageId,
  });

  @override
  List<Object?> get props => [courseId, courseName, lastPlayedAt, packageId];
}

// ─── Load Initial Data ────────────────────────────────────────────────────────

/// Load initial data: active bag, primary player, suggested start hole.
class LoadInitialData extends RoundSetupEvent {
  const LoadInitialData({
    this.initialCourseId,
    this.initialCourseName,
    this.initialPackageId,
  });

  /// When provided, the round is pre-configured for this course as soon as the
  /// initial state is built (avoids a CourseSelected race against the load).
  final int? initialCourseId;
  final String? initialCourseName;
  final String? initialPackageId;

  @override
  List<Object?> get props => [
    initialCourseId,
    initialCourseName,
    initialPackageId,
  ];
}
