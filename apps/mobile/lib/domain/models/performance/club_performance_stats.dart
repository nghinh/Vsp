// ClubPerformanceStats — VSP Mobile App
//
// Domain model for per-club performance statistics.
// Per Story 11.1 AC-1: all statistical fields plus sample quality and lock state.

import 'package:equatable/equatable.dart';

/// Sample size labels per Story 11.1 Slice 1.
/// Used to display insufficient/limited/moderate/robust badges.
enum SampleSizeLabel {
  insufficient, // <5 shots
  limited, // 5-9 shots
  moderate, // 10-29 shots
  robust, // >=30 shots
}

/// Confidence levels for performance stats reliability.
/// Per Story 11.1 AC-2.
enum ConfidenceLevel {
  insufficient, // <5 shots
  low, // 5-9 shots
  medium, // 10-29 shots
  high, // >=30 shots
}

/// Domain model for club performance statistics.
/// All distance values are stored in meters (API contract).
class ClubPerformanceStats extends Equatable {
  final int clubId;
  final int bagId;

  // ─── Sample Quality ───────────────────────────────────────────────────────

  final int sampleSize;
  final SampleSizeLabel sampleSizeLabel;
  final ConfidenceLevel confidenceLevel;
  final bool recommendationsLocked;

  // ─── Carry Distance Stats (meters) ───────────────────────────────────────

  final double? carryAvg;
  final double? carryMedian;
  final double? carryStdDev;
  final double? carryMin;
  final double? carryMax;

  // ─── Total Distance Stats (meters) ────────────────────────────────────────

  final double? totalAvg;
  final double? totalMedian;
  final double? totalStdDev;
  final double? totalMin;
  final double? totalMax;

  // ─── Directional Deviation Stats (meters) ────────────────────────────────

  /// Left/right deviation average (negative=left, positive=right).
  final double? leftRightAvg;

  /// Left/right standard deviation.
  final double? leftRightStdDev;

  /// Short/long deviation average (negative=short, positive=long).
  final double? shortLongAvg;

  /// Short/long standard deviation.
  final double? shortLongStdDev;

  // ─── Timestamps ───────────────────────────────────────────────────────────

  final DateTime? computedAt;
  final DateTime? basedOnShotAt;

  const ClubPerformanceStats({
    required this.clubId,
    required this.bagId,
    required this.sampleSize,
    required this.sampleSizeLabel,
    required this.confidenceLevel,
    required this.recommendationsLocked,
    this.carryAvg,
    this.carryMedian,
    this.carryStdDev,
    this.carryMin,
    this.carryMax,
    this.totalAvg,
    this.totalMedian,
    this.totalStdDev,
    this.totalMin,
    this.totalMax,
    this.leftRightAvg,
    this.leftRightStdDev,
    this.shortLongAvg,
    this.shortLongStdDev,
    this.computedAt,
    this.basedOnShotAt,
  });

  /// Format carry average for display in the given unit.
  String formatCarryAvg({String unit = 'meters'}) {
    if (carryAvg == null) return '—';
    return _formatDistance(carryAvg!, unit);
  }

  /// Format carry median for display in the given unit.
  String formatCarryMedian({String unit = 'meters'}) {
    if (carryMedian == null) return '—';
    return _formatDistance(carryMedian!, unit);
  }

  /// Format total average for display in the given unit.
  String formatTotalAvg({String unit = 'meters'}) {
    if (totalAvg == null) return '—';
    return _formatDistance(totalAvg!, unit);
  }

  /// Format total median for display in the given unit.
  String formatTotalMedian({String unit = 'meters'}) {
    if (totalMedian == null) return '—';
    return _formatDistance(totalMedian!, unit);
  }

  /// Format variability (stdDev) for display.
  String formatVariability({String unit = 'meters'}) {
    if (carryStdDev == null) return '—';
    return '±${_formatDistance(carryStdDev!, unit)}';
  }

  /// Format left/right deviation.
  String formatLeftRight() {
    if (leftRightAvg == null) return '—';
    final sign = leftRightAvg! >= 0 ? '+' : '';
    return '$sign${_formatMeters(leftRightAvg!)}';
  }

  /// Format short/long deviation.
  String formatShortLong() {
    if (shortLongAvg == null) return '—';
    final sign = shortLongAvg! >= 0 ? '+' : '';
    return '$sign${_formatMeters(shortLongAvg!)}';
  }

  String _formatDistance(double meters, String unit) {
    if (unit == 'yards') {
      return '${(meters * 1.09361).round()} yd';
    }
    return '${meters.round()} m';
  }

  String _formatMeters(double meters) {
    return '${meters.round()} m';
  }

  /// Parse SampleSizeLabel from API string value.
  static SampleSizeLabel parseSampleSizeLabel(String? value) {
    switch (value?.toLowerCase()) {
      case 'insufficient':
        return SampleSizeLabel.insufficient;
      case 'limited':
        return SampleSizeLabel.limited;
      case 'moderate':
        return SampleSizeLabel.moderate;
      case 'robust':
        return SampleSizeLabel.robust;
      default:
        return SampleSizeLabel.insufficient;
    }
  }

  /// Parse ConfidenceLevel from API string value.
  static ConfidenceLevel parseConfidenceLevel(String? value) {
    switch (value?.toLowerCase()) {
      case 'insufficient':
        return ConfidenceLevel.insufficient;
      case 'low':
        return ConfidenceLevel.low;
      case 'medium':
        return ConfidenceLevel.medium;
      case 'high':
        return ConfidenceLevel.high;
      default:
        return ConfidenceLevel.insufficient;
    }
  }

  @override
  List<Object?> get props => [
    clubId,
    bagId,
    sampleSize,
    sampleSizeLabel,
    confidenceLevel,
    recommendationsLocked,
    carryAvg,
    carryMedian,
    carryStdDev,
    carryMin,
    carryMax,
    totalAvg,
    totalMedian,
    totalStdDev,
    totalMin,
    totalMax,
    leftRightAvg,
    leftRightStdDev,
    shortLongAvg,
    shortLongStdDev,
    computedAt,
    basedOnShotAt,
  ];
}

/// Domain model for bag-level performance (all clubs).
class BagPerformance extends Equatable {
  final int bagId;
  final List<ClubPerformanceStats> clubs;

  const BagPerformance({required this.bagId, required this.clubs});

  @override
  List<Object?> get props => [bagId, clubs];
}
