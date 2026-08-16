// Round Model — VSP Mobile App
//
// Local round entity for offline-first round persistence.
// Stored in vsp_round.db.
//
// Story 5.2: Persist Round Locally
// Story 12.1 Slice F: tournamentId, tournamentPolicyVersion, tournamentPolicyJson

import 'dart:convert';
import 'package:equatable/equatable.dart';

import 'tournament_policy.dart';

/// Round lifecycle status.
enum RoundStatus { inProgress, completed, abandoned, cancelled }

/// Round entity — represents one golf round.
class Round extends Equatable {
  final String id; // UUID, local identifier
  final int courseId;

  /// The second đường, where the round pairs two nines.
  ///
  /// Long Biên has three of them and a round there is a pairing chosen on the
  /// day, so round hole 10 is hole 1 of whichever nine came second. The round
  /// setup screen has always known this and passed it into the round; the
  /// round itself did not carry it, so resuming one left holes 10 to 18
  /// belonging to no course. The map asked the front nine for its hole 10,
  /// which does not exist, and said the hole had not been surveyed.
  ///
  /// Null for an eighteen played on one course, which is most of them.
  final int? backNineCourseId;
  final String courseName; // denormalized from course package
  final RoundStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String packageVersion; // captured at round start for guard
  final String? tournamentPolicyId; // null for casual/practice rounds
  /// Tournament ID — links this round to a tournament event.
  /// Per Story 12.1 Slice F.
  final String? tournamentId;

  /// Version of the tournament policy at round creation time.
  /// Used to detect mid-round policy changes.
  /// Per Story 12.1 Slice F.
  final int? tournamentPolicyVersion;

  /// Cached tournament policy JSON for offline restricted feature checks.
  /// Per Story 12.1 Slice F.
  final TournamentPolicy? tournamentPolicy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Round({
    required this.id,
    required this.courseId,
    this.backNineCourseId,
    required this.courseName,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.packageVersion,
    this.tournamentPolicyId,
    this.tournamentId,
    this.tournamentPolicyVersion,
    this.tournamentPolicy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True if this round is still in progress.
  bool get isActive => status == RoundStatus.inProgress;

  /// True if this is a tournament round (has a tournament policy).
  bool get isTournamentRound => tournamentPolicyId != null;

  /// Copy with updated fields.
  Round copyWith({
    String? id,
    int? courseId,
    int? backNineCourseId,
    String? courseName,
    RoundStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? packageVersion,
    String? tournamentPolicyId,
    String? tournamentId,
    int? tournamentPolicyVersion,
    TournamentPolicy? tournamentPolicy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Round(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      backNineCourseId: backNineCourseId ?? this.backNineCourseId,
      courseName: courseName ?? this.courseName,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      packageVersion: packageVersion ?? this.packageVersion,
      tournamentPolicyId: tournamentPolicyId ?? this.tournamentPolicyId,
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentPolicyVersion:
          tournamentPolicyVersion ?? this.tournamentPolicyVersion,
      tournamentPolicy: tournamentPolicy ?? this.tournamentPolicy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'back_nine_course_id': backNineCourseId,
      'course_name': courseName,
      'status': status.name,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'package_version': packageVersion,
      'tournament_policy_id': tournamentPolicyId,
      'tournament_id': tournamentId,
      'tournament_policy_version': tournamentPolicyVersion,
      'tournament_policy_json': tournamentPolicy != null
          ? jsonEncode(tournamentPolicy!.toJson())
          : null,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Reconstruct from a SQLite row.
  factory Round.fromMap(Map<String, dynamic> map) {
    TournamentPolicy? policy;
    if (map['tournament_policy_json'] != null) {
      try {
        policy = TournamentPolicy.fromJson(
          jsonDecode(map['tournament_policy_json'] as String)
              as Map<String, dynamic>,
        );
      } catch (_) {
        policy = null;
      }
    }
    return Round(
      id: map['id'] as String,
      courseId: (map['course_id'] as num).toInt(),
      // Absent on a row written before this column existed, which every
      // in-progress round on an installed app is.
      backNineCourseId: (map['back_nine_course_id'] as num?)?.toInt(),
      courseName: map['course_name'] as String,
      status: RoundStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RoundStatus.inProgress,
      ),
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      packageVersion: map['package_version'] as String,
      tournamentPolicyId: map['tournament_policy_id'] as String?,
      tournamentId: map['tournament_id'] as String?,
      tournamentPolicyVersion: (map['tournament_policy_version'] as num?)
          ?.toInt(),
      tournamentPolicy: policy,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    backNineCourseId,
    courseName,
    status,
    startedAt,
    endedAt,
    packageVersion,
    tournamentPolicyId,
    tournamentId,
    tournamentPolicyVersion,
    tournamentPolicy,
    createdAt,
    updatedAt,
  ];
}
