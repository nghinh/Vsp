// Shot Metrics Model — VSP Mobile App
//
// Shot-level aggregations for club usage, distances, and lies.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
//
// Aggregates shot data by club for usage patterns and distance distributions.

import 'package:equatable/equatable.dart';

/// Distance distribution bucket for a club.
class DistanceBucket extends Equatable {
  final double minYards;
  final double maxYards;
  final int shotCount;
  final double percentage;

  const DistanceBucket({
    required this.minYards,
    required this.maxYards,
    required this.shotCount,
    required this.percentage,
  });

  String get label => '${minYards.round()}-${maxYards.round()} yds';

  @override
  List<Object?> get props => [minYards, maxYards, shotCount, percentage];

  Map<String, dynamic> toJson() => {
    'minYards': minYards,
    'maxYards': maxYards,
    'shotCount': shotCount,
    'percentage': percentage,
  };

  factory DistanceBucket.fromJson(Map<String, dynamic> json) {
    return DistanceBucket(
      minYards: (json['minYards'] as num).toDouble(),
      maxYards: (json['maxYards'] as num).toDouble(),
      shotCount: (json['shotCount'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

/// Lie distribution entry for a club.
class LieDistribution extends Equatable {
  final String lie;
  final int shotCount;
  final double percentage;

  const LieDistribution({
    required this.lie,
    required this.shotCount,
    required this.percentage,
  });

  @override
  List<Object?> get props => [lie, shotCount, percentage];

  Map<String, dynamic> toJson() => {
    'lie': lie,
    'shotCount': shotCount,
    'percentage': percentage,
  };

  factory LieDistribution.fromJson(Map<String, dynamic> json) {
    return LieDistribution(
      lie: json['lie'] as String,
      shotCount: (json['shotCount'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

/// Aggregated shot metrics for a single club.
class ClubShotMetrics extends Equatable {
  final String clubId;
  final String? clubName;
  final int totalShots;
  final double? averageDistanceYards;
  final double? averageDistanceMeters;
  final double? medianDistanceYards;
  final double? minDistanceYards;
  final double? maxDistanceYards;
  final double? standardDeviationYards;
  final List<DistanceBucket> distanceDistribution;
  final List<LieDistribution> lieDistribution;
  final int? bestResultCount; // fairwayHit or greenHit
  final double? bestResultRate;

  const ClubShotMetrics({
    required this.clubId,
    this.clubName,
    required this.totalShots,
    this.averageDistanceYards,
    this.averageDistanceMeters,
    this.medianDistanceYards,
    this.minDistanceYards,
    this.maxDistanceYards,
    this.standardDeviationYards,
    this.distanceDistribution = const [],
    this.lieDistribution = const [],
    this.bestResultCount,
    this.bestResultRate,
  });

  /// Consistency score: lower std dev = more consistent (0-100 scale).
  double? get consistencyScore {
    if (standardDeviationYards == null || averageDistanceYards == null) {
      return null;
    }
    if (averageDistanceYards == 0) return null;
    // Coefficient of variation inverted to 0-100 scale
    final cv = standardDeviationYards! / averageDistanceYards!;
    return (1 - cv.clamp(0.0, 1.0)) * 100;
  }

  @override
  List<Object?> get props => [
    clubId,
    clubName,
    totalShots,
    averageDistanceYards,
    averageDistanceMeters,
    medianDistanceYards,
    minDistanceYards,
    maxDistanceYards,
    standardDeviationYards,
    distanceDistribution,
    lieDistribution,
    bestResultCount,
    bestResultRate,
  ];

  Map<String, dynamic> toJson() => {
    'clubId': clubId,
    'clubName': clubName,
    'totalShots': totalShots,
    'averageDistanceYards': averageDistanceYards,
    'averageDistanceMeters': averageDistanceMeters,
    'medianDistanceYards': medianDistanceYards,
    'minDistanceYards': minDistanceYards,
    'maxDistanceYards': maxDistanceYards,
    'standardDeviationYards': standardDeviationYards,
    'distanceDistribution': distanceDistribution
        .map((d) => d.toJson())
        .toList(),
    'lieDistribution': lieDistribution.map((l) => l.toJson()).toList(),
    'bestResultCount': bestResultCount,
    'bestResultRate': bestResultRate,
  };

  factory ClubShotMetrics.fromJson(Map<String, dynamic> json) {
    return ClubShotMetrics(
      clubId: json['clubId'] as String,
      clubName: json['clubName'] as String?,
      totalShots: (json['totalShots'] as num).toInt(),
      averageDistanceYards: (json['averageDistanceYards'] as num?)?.toDouble(),
      averageDistanceMeters: (json['averageDistanceMeters'] as num?)
          ?.toDouble(),
      medianDistanceYards: (json['medianDistanceYards'] as num?)?.toDouble(),
      minDistanceYards: (json['minDistanceYards'] as num?)?.toDouble(),
      maxDistanceYards: (json['maxDistanceYards'] as num?)?.toDouble(),
      standardDeviationYards: (json['standardDeviationYards'] as num?)
          ?.toDouble(),
      distanceDistribution:
          (json['distanceDistribution'] as List<dynamic>?)
              ?.map((e) => DistanceBucket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      lieDistribution:
          (json['lieDistribution'] as List<dynamic>?)
              ?.map((e) => LieDistribution.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      bestResultCount: (json['bestResultCount'] as num?)?.toInt(),
      bestResultRate: (json['bestResultRate'] as num?)?.toDouble(),
    );
  }
}

/// Aggregated shot metrics for a round or time period.
class ShotMetrics extends Equatable {
  final String? roundId;
  final String? playerId;
  final List<ClubShotMetrics> clubMetrics;
  final int totalShots;
  final DateTime? fromDate;
  final DateTime? toDate;

  const ShotMetrics({
    this.roundId,
    this.playerId,
    this.clubMetrics = const [],
    this.totalShots = 0,
    this.fromDate,
    this.toDate,
  });

  /// Most-used club by shot count.
  ClubShotMetrics? get mostUsedClub {
    if (clubMetrics.isEmpty) return null;
    return clubMetrics.reduce((a, b) => a.totalShots >= b.totalShots ? a : b);
  }

  /// Longest average distance club.
  ClubShotMetrics? get longestClub {
    if (clubMetrics.isEmpty) return null;
    ClubShotMetrics? longest;
    for (final club in clubMetrics) {
      if (club.averageDistanceYards != null) {
        if (longest == null ||
            club.averageDistanceYards! > (longest.averageDistanceYards ?? 0)) {
          longest = club;
        }
      }
    }
    return longest;
  }

  /// Most consistent club (highest consistency score).
  ClubShotMetrics? get mostConsistentClub {
    if (clubMetrics.isEmpty) return null;
    ClubShotMetrics? mostConsistent;
    for (final club in clubMetrics) {
      if (club.consistencyScore != null) {
        if (mostConsistent == null ||
            club.consistencyScore! > (mostConsistent.consistencyScore ?? 0)) {
          mostConsistent = club;
        }
      }
    }
    return mostConsistent;
  }

  /// Number of clubs with at least one shot.
  int get clubsUsed => clubMetrics.length;

  @override
  List<Object?> get props => [
    roundId,
    playerId,
    clubMetrics,
    totalShots,
    fromDate,
    toDate,
  ];

  Map<String, dynamic> toJson() => {
    'roundId': roundId,
    'playerId': playerId,
    'clubMetrics': clubMetrics.map((c) => c.toJson()).toList(),
    'totalShots': totalShots,
    'fromDate': fromDate?.toIso8601String(),
    'toDate': toDate?.toIso8601String(),
  };

  factory ShotMetrics.fromJson(Map<String, dynamic> json) {
    return ShotMetrics(
      roundId: json['roundId'] as String?,
      playerId: json['playerId'] as String?,
      clubMetrics:
          (json['clubMetrics'] as List<dynamic>?)
              ?.map((e) => ClubShotMetrics.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalShots: (json['totalShots'] as num?)?.toInt() ?? 0,
      fromDate: json['fromDate'] != null
          ? DateTime.parse(json['fromDate'] as String)
          : null,
      toDate: json['toDate'] != null
          ? DateTime.parse(json['toDate'] as String)
          : null,
    );
  }
}
