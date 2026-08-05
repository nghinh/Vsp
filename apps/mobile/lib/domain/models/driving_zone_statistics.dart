// Driving Zone Statistics Model — VSP Mobile App
//
// Aggregated landing zone statistics per club per hole-zone.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
//
// Aggregates shot end-location data into zones (left/center/right)
// and distance bands (short/mid/long) for each club.

import 'package:equatable/equatable.dart';

import 'driving_zone_filter.dart';

/// Represents a zone grid cell for landing area analysis.
class ZoneCell extends Equatable {
  /// Horizontal zone: left (-1), center (0), right (1).
  final int horizontalZone;

  /// Distance band: short (0), mid (1), long (2).
  final int distanceBand;

  /// Number of shots landing in this cell.
  final int shotCount;

  /// Percentage of total shots in this cell.
  final double percentage;

  const ZoneCell({
    required this.horizontalZone,
    required this.distanceBand,
    required this.shotCount,
    required this.percentage,
  });

  /// Horizontal zone label for display.
  String get horizontalLabel {
    switch (horizontalZone) {
      case -1:
        return 'Left';
      case 0:
        return 'Center';
      case 1:
        return 'Right';
      default:
        return 'Unknown';
    }
  }

  /// Distance band label for display.
  String get distanceLabel {
    switch (distanceBand) {
      case 0:
        return 'Short';
      case 1:
        return 'Mid';
      case 2:
        return 'Long';
      default:
        return 'Unknown';
    }
  }

  /// Combined zone description.
  String get description => '$horizontalLabel / $distanceLabel';

  @override
  List<Object?> get props => [
    horizontalZone,
    distanceBand,
    shotCount,
    percentage,
  ];

  Map<String, dynamic> toJson() => {
    'horizontalZone': horizontalZone,
    'distanceBand': distanceBand,
    'shotCount': shotCount,
    'percentage': percentage,
  };

  factory ZoneCell.fromJson(Map<String, dynamic> json) {
    return ZoneCell(
      horizontalZone: (json['horizontalZone'] as num).toInt(),
      distanceBand: (json['distanceBand'] as num).toInt(),
      shotCount: (json['shotCount'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

/// Per-hole driving zone statistics for a single club.
class HoleZoneStats extends Equatable {
  final int holeNumber;
  final String clubId;
  final String? clubName;
  final int totalShots;
  final List<ZoneCell> zoneCells;
  final double? averageDistanceYards;
  final double? averageDistanceMeters;
  final DateTime? lastUpdated;

  const HoleZoneStats({
    required this.holeNumber,
    required this.clubId,
    this.clubName,
    required this.totalShots,
    required this.zoneCells,
    this.averageDistanceYards,
    this.averageDistanceMeters,
    this.lastUpdated,
  });

  /// Percentage of shots hit in the "ideal" center zone.
  double get centerZonePercentage {
    final centerCells = zoneCells.where((c) => c.horizontalZone == 0);
    if (centerCells.isEmpty) return 0.0;
    return centerCells.fold(0.0, (sum, c) => sum + c.percentage);
  }

  /// Dispersion index: higher = more scattered.
  double get dispersionIndex {
    if (zoneCells.isEmpty) return 0.0;
    // Variance of zone percentages as a dispersion measure
    final avgPct = 100.0 / zoneCells.length;
    final variance = zoneCells.fold(
      0.0,
      (sum, c) => sum + (c.percentage - avgPct) * (c.percentage - avgPct),
    );
    return variance;
  }

  @override
  List<Object?> get props => [
    holeNumber,
    clubId,
    clubName,
    totalShots,
    zoneCells,
    averageDistanceYards,
    averageDistanceMeters,
    lastUpdated,
  ];

  Map<String, dynamic> toJson() => {
    'holeNumber': holeNumber,
    'clubId': clubId,
    'clubName': clubName,
    'totalShots': totalShots,
    'zoneCells': zoneCells.map((c) => c.toJson()).toList(),
    'averageDistanceYards': averageDistanceYards,
    'averageDistanceMeters': averageDistanceMeters,
    'lastUpdated': lastUpdated?.toIso8601String(),
  };

  factory HoleZoneStats.fromJson(Map<String, dynamic> json) {
    return HoleZoneStats(
      holeNumber: (json['holeNumber'] as num).toInt(),
      clubId: json['clubId'] as String,
      clubName: json['clubName'] as String?,
      totalShots: (json['totalShots'] as num).toInt(),
      zoneCells: (json['zoneCells'] as List<dynamic>? ?? const [])
          .map((e) => ZoneCell.fromJson(e as Map<String, dynamic>))
          .toList(),
      averageDistanceYards: (json['averageDistanceYards'] as num?)?.toDouble(),
      averageDistanceMeters: (json['averageDistanceMeters'] as num?)
          ?.toDouble(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }
}

/// Aggregated driving zone statistics for a filter.
class DrivingZoneStatistics extends Equatable {
  final DrivingZoneFilter filter;
  final List<HoleZoneStats> holeStats;
  final DateTime generatedAt;
  final bool isSampleInsufficient;

  const DrivingZoneStatistics({
    required this.filter,
    required this.holeStats,
    required this.generatedAt,
    this.isSampleInsufficient = false,
  });

  /// Total shots across all holes.
  int get totalShots => holeStats.fold(0, (sum, h) => sum + h.totalShots);

  /// Average dispersion across all clubs.
  double get averageDispersion {
    if (holeStats.isEmpty) return 0.0;
    return holeStats.fold(0.0, (sum, h) => sum + h.dispersionIndex) /
        holeStats.length;
  }

  /// Clubs represented in the statistics.
  List<String> get clubIds => holeStats.map((h) => h.clubId).toSet().toList();

  @override
  List<Object?> get props => [
    filter,
    holeStats,
    generatedAt,
    isSampleInsufficient,
  ];

  Map<String, dynamic> toJson() => {
    'filter': filter.toJson(),
    'holeStats': holeStats.map((h) => h.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
    'isSampleInsufficient': isSampleInsufficient,
  };

  factory DrivingZoneStatistics.fromJson(Map<String, dynamic> json) {
    return DrivingZoneStatistics(
      filter: DrivingZoneFilter.fromJson(
        json['filter'] as Map<String, dynamic>,
      ),
      holeStats: (json['holeStats'] as List<dynamic>? ?? const [])
          .map((e) => HoleZoneStats.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      isSampleInsufficient: json['isSampleInsufficient'] as bool? ?? false,
    );
  }
}
