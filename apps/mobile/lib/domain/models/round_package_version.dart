// Round Package Version Model — VSP Mobile App
//
// Tracks which package version was active when a round started for a course.
// Used by the active round guard to prevent silent package updates during active rounds.
//
// Story 4.4 INC-MOBILE-GUARD: prevents package version changes during active rounds.

import 'package:equatable/equatable.dart';

/// Records the package version that was active when a round started for a course.
///
/// Stored locally to detect when a round is in progress and block
/// package version promotion until the round completes.
class RoundPackageVersion extends Equatable {
  final int courseId;
  final String packageVersion;
  final DateTime startedAt;
  final String? roundId;

  const RoundPackageVersion({
    required this.courseId,
    required this.packageVersion,
    required this.startedAt,
    this.roundId,
  });

  /// True if this record is for an active (not yet completed) round.
  /// For local tracking, we assume rounds are active until explicitly completed.
  bool get isActive => true;

  @override
  List<Object?> get props => [courseId, packageVersion, startedAt, roundId];
}
