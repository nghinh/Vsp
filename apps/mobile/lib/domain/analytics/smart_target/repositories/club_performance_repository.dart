// ClubPerformanceRepository Interface — VSP Mobile App
//
// Repository interface for club performance and dispersion data (Story 11.1).
//
// Story 11.4 — Slice 1: Data Access Interfaces

import 'package:equatable/equatable.dart';

/// Club performance statistics for a single club.
class ClubPerformanceStats extends Equatable {
  final String clubId;
  final String clubName;
  final double? loftDegrees;
  final double avgCarryMeters;
  final double medianCarryMeters;
  final double dispersionMeters;
  final double leftBiasMeters;
  final double rightBiasMeters;
  final int sampleCount;
  final double confidence;

  const ClubPerformanceStats({
    required this.clubId,
    required this.clubName,
    this.loftDegrees,
    required this.avgCarryMeters,
    required this.medianCarryMeters,
    required this.dispersionMeters,
    required this.leftBiasMeters,
    required this.rightBiasMeters,
    required this.sampleCount,
    required this.confidence,
  });

  factory ClubPerformanceStats.fromJson(Map<String, dynamic> json) {
    return ClubPerformanceStats(
      clubId: json['clubId'] as String,
      clubName: json['clubName'] as String,
      loftDegrees: (json['loftDegrees'] as num?)?.toDouble(),
      avgCarryMeters: (json['avgCarryMeters'] as num).toDouble(),
      medianCarryMeters: (json['medianCarryMeters'] as num).toDouble(),
      dispersionMeters: (json['dispersionMeters'] as num).toDouble(),
      leftBiasMeters: (json['leftBiasMeters'] as num).toDouble(),
      rightBiasMeters: (json['rightBiasMeters'] as num).toDouble(),
      sampleCount: json['sampleCount'] as int,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'clubId': clubId,
    'clubName': clubName,
    'loftDegrees': loftDegrees,
    'avgCarryMeters': avgCarryMeters,
    'medianCarryMeters': medianCarryMeters,
    'dispersionMeters': dispersionMeters,
    'leftBiasMeters': leftBiasMeters,
    'rightBiasMeters': rightBiasMeters,
    'sampleCount': sampleCount,
    'confidence': confidence,
  };

  @override
  List<Object?> get props => [
    clubId,
    clubName,
    loftDegrees,
    avgCarryMeters,
    medianCarryMeters,
    dispersionMeters,
    leftBiasMeters,
    rightBiasMeters,
    sampleCount,
    confidence,
  ];
}

/// Repository interface for club performance data.
///
/// Consumed by Smart Target generator to filter clubs by carry range
/// and compute risk scores based on dispersion.
abstract class ClubPerformanceRepository {
  /// Get performance stats for a specific club.
  Future<ClubPerformanceStats?> getByClubId(String clubId);

  /// Get all clubs with performance stats for a player.
  Future<List<ClubPerformanceStats>> getAllForPlayer(String playerId);

  /// Get clubs filtered by minimum sample count for reliability.
  Future<List<ClubPerformanceStats>> getReliableClubs(
    String playerId, {
    int minSampleCount = 5,
  });

  /// Check if enough data exists for Smart Target generation.
  Future<bool> hasSufficientData(String playerId, {int minClubs = 3});
}
