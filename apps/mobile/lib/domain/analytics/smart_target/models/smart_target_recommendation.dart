// SmartTargetRecommendation Model — VSP Mobile App
//
// Top-level output of the Smart Target generator.
//
// Story 11.4 — Slice 0: Domain Models

import 'package:equatable/equatable.dart';

import 'strategy_option.dart';

/// Reason why Smart Target is unavailable.
enum UnavailabilityReason {
  /// Feature disabled by tournament policy.
  restrictedByPolicy('restricted_by_policy'),

  /// Not enough round history to compute reliable recommendations.
  insufficientHistory('insufficient_history'),

  /// No hole geometry data available.
  noHoleData('no_hole_data'),

  /// Golfer position not available.
  noGolferPosition('no_golfer_position'),

  /// Club performance data not yet synced.
  noClubPerformanceData('no_club_performance_data'),

  /// Unknown error.
  unknown('unknown');

  final String value;
  const UnavailabilityReason(this.value);

  static UnavailabilityReason? fromValue(String? value) {
    if (value == null) return null;
    return UnavailabilityReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UnavailabilityReason.unknown,
    );
  }
}

/// Top-level Smart Target recommendation output.
class SmartTargetRecommendation extends Equatable {
  /// Whether a recommendation is available.
  final bool available;

  /// Reason for unavailability (null when available = true).
  final UnavailabilityReason? reason;

  /// Human-readable reason string for display.
  final String? reasonLabel;

  /// Strategy options (safe, balanced, aggressive). Null when unavailable.
  final List<StrategyOption>? strategyOptions;

  /// Timestamp when this recommendation was generated.
  final DateTime generatedAt;

  /// Data source versions used for traceability.
  final Map<String, String>? dataSourceVersions;

  const SmartTargetRecommendation({
    required this.available,
    this.reason,
    this.reasonLabel,
    this.strategyOptions,
    required this.generatedAt,
    this.dataSourceVersions,
  });

  /// Factory for an unavailable recommendation.
  factory SmartTargetRecommendation.unavailable({
    required UnavailabilityReason reason,
    String? reasonLabel,
    DateTime? generatedAt,
  }) {
    return SmartTargetRecommendation(
      available: false,
      reason: reason,
      reasonLabel: reasonLabel,
      strategyOptions: null,
      generatedAt: generatedAt ?? DateTime.now(),
      dataSourceVersions: null,
    );
  }

  /// Factory for an available recommendation.
  factory SmartTargetRecommendation.available({
    required List<StrategyOption> strategyOptions,
    Map<String, String>? dataSourceVersions,
    DateTime? generatedAt,
  }) {
    return SmartTargetRecommendation(
      available: true,
      reason: null,
      reasonLabel: null,
      strategyOptions: strategyOptions,
      generatedAt: generatedAt ?? DateTime.now(),
      dataSourceVersions: dataSourceVersions,
    );
  }

  /// True if recommendation is restricted by tournament policy.
  bool get isRestrictedByPolicy =>
      reason == UnavailabilityReason.restrictedByPolicy;

  /// True if recommendation is unavailable due to insufficient history.
  bool get isInsufficientHistory =>
      reason == UnavailabilityReason.insufficientHistory;

  // ─── JSON ─────────────────────────────────────────────────────────────────

  factory SmartTargetRecommendation.fromJson(Map<String, dynamic> json) {
    final isAvailable = json['available'] as bool? ?? false;
    if (!isAvailable) {
      return SmartTargetRecommendation.unavailable(
        reason:
            UnavailabilityReason.fromValue(json['reason'] as String?) ??
            UnavailabilityReason.unknown,
        reasonLabel: json['reasonLabel'] as String?,
        generatedAt: json['generatedAt'] != null
            ? DateTime.parse(json['generatedAt'] as String)
            : null,
      );
    }
    return SmartTargetRecommendation.available(
      strategyOptions: (json['strategyOptions'] as List<dynamic>)
          .map((e) => StrategyOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataSourceVersions: (json['dataSourceVersions'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as String)),
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'available': available,
    if (reason != null) 'reason': reason!.value,
    if (reasonLabel != null) 'reasonLabel': reasonLabel,
    if (strategyOptions != null)
      'strategyOptions': strategyOptions!.map((e) => e.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
    if (dataSourceVersions != null) 'dataSourceVersions': dataSourceVersions,
  };

  @override
  List<Object?> get props => [
    available,
    reason,
    reasonLabel,
    strategyOptions,
    generatedAt,
    dataSourceVersions,
  ];
}
