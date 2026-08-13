// ClubPerformanceStats — VSP Mobile App
//
// Domain model for per-club performance statistics.
// Per Story 11.1 AC-1: all statistical fields plus sample quality and lock state.

import 'package:equatable/equatable.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

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

  /// Carry average in [unit], or an em dash where there is nothing to average.
  ///
  /// These took a `'meters'`/`'yards'` string that defaulted to metres, and
  /// nothing in the app ever passed one: `PerformanceBloc` emits its state
  /// without a unit, so every statistic on every screen printed metres no
  /// matter what the golfer had saved. Taking [DistanceUnit] means the compiler
  /// asks the caller the question the default used to answer wrongly.
  String formatCarryAvg(DistanceUnit unit) => _format(carryAvg, unit);

  /// Carry median in [unit].
  String formatCarryMedian(DistanceUnit unit) => _format(carryMedian, unit);

  /// Total average in [unit].
  String formatTotalAvg(DistanceUnit unit) => _format(totalAvg, unit);

  /// Total median in [unit].
  String formatTotalMedian(DistanceUnit unit) => _format(totalMedian, unit);

  /// Carry spread in [unit], as a signed tolerance.
  String formatVariability(DistanceUnit unit) => carryStdDev == null
      ? '—'
      : MeasureUnits.formatTolerance(carryStdDev!, unit);

  /// Average miss left (negative) or right (positive), in [unit].
  String formatLeftRight(DistanceUnit unit) => _signed(leftRightAvg, unit);

  /// Average miss short (negative) or long (positive), in [unit].
  String formatShortLong(DistanceUnit unit) => _signed(shortLongAvg, unit);

  String _format(double? meters, DistanceUnit unit) =>
      meters == null ? '—' : MeasureUnits.format(meters, unit);

  /// A miss is a direction as much as a distance, so the sign is kept.
  String _signed(double? meters, DistanceUnit unit) {
    if (meters == null) return '—';
    final sign = meters >= 0 ? '+' : '';
    return '$sign${MeasureUnits.format(meters, unit)}';
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
