// Tournament Model — VSP Mobile App
//
// Domain model for a tournament event.
// Per Story 12.1 AC.
//
// Story 12.1 Slice F

import 'package:equatable/equatable.dart';

import 'tournament_format.dart';
import 'tournament_status.dart';

/// A tournament event — owns the tournament policy, players, flights, and results.
/// Per Story 12.1.
class Tournament extends Equatable {
  final String id;
  final String name;
  final TournamentFormat format;
  final TournamentStatus status;
  final int courseId;
  final String? courseName; // denormalized for display
  final DateTime startDate;
  final DateTime endDate;
  final String? tournamentPolicyId;
  final DateTime? registrationDeadline;
  final int? maxPlayers;
  final String? description;
  final DateTime createdAt;
  final int createdBy;
  final int version;

  /// Current leaderboard version — mobile can detect stale leaderboard.
  final int leaderboardVersion;

  const Tournament({
    required this.id,
    required this.name,
    required this.format,
    required this.status,
    required this.courseId,
    this.courseName,
    required this.startDate,
    required this.endDate,
    this.tournamentPolicyId,
    this.registrationDeadline,
    this.maxPlayers,
    this.description,
    required this.createdAt,
    required this.createdBy,
    this.version = 1,
    this.leaderboardVersion = 0,
  });

  /// True if this tournament is currently accepting registrations.
  bool get isRegistrationOpen =>
      status == TournamentStatus.registrationOpen &&
      (registrationDeadline == null ||
          registrationDeadline!.isAfter(DateTime.now()));

  /// True if the tournament is active (in progress).
  bool get isActive => status == TournamentStatus.inProgress;

  /// Parse from API JSON response.
  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'] as String,
      name: json['name'] as String,
      format: TournamentFormatExtension.fromString(json['format'] as String),
      status: TournamentStatusExtension.fromString(json['status'] as String),
      courseId: json['courseId'] is String
          ? int.parse(json['courseId'] as String)
          : (json['courseId'] as num).toInt(),
      courseName: json['courseName'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      tournamentPolicyId: json['tournamentPolicyId'] as String?,
      registrationDeadline: json['registrationDeadline'] != null
          ? DateTime.parse(json['registrationDeadline'] as String)
          : null,
      maxPlayers: (json['maxPlayers'] as num?)?.toInt(),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] is String
          ? int.parse(json['createdBy'] as String)
          : (json['createdBy'] as num).toInt(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      leaderboardVersion: (json['leaderboardVersion'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'format': format.name,
    'status': status.name,
    'courseId': courseId,
    'courseName': courseName,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'tournamentPolicyId': tournamentPolicyId,
    'registrationDeadline': registrationDeadline?.toIso8601String(),
    'maxPlayers': maxPlayers,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
    'version': version,
    'leaderboardVersion': leaderboardVersion,
  };

  Tournament copyWith({
    String? id,
    String? name,
    TournamentFormat? format,
    TournamentStatus? status,
    int? courseId,
    String? courseName,
    DateTime? startDate,
    DateTime? endDate,
    String? tournamentPolicyId,
    DateTime? registrationDeadline,
    int? maxPlayers,
    String? description,
    DateTime? createdAt,
    int? createdBy,
    int? version,
    int? leaderboardVersion,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      format: format ?? this.format,
      status: status ?? this.status,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      tournamentPolicyId: tournamentPolicyId ?? this.tournamentPolicyId,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      version: version ?? this.version,
      leaderboardVersion: leaderboardVersion ?? this.leaderboardVersion,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    format,
    status,
    courseId,
    courseName,
    startDate,
    endDate,
    tournamentPolicyId,
    registrationDeadline,
    maxPlayers,
    description,
    createdAt,
    createdBy,
    version,
    leaderboardVersion,
  ];
}
