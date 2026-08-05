// Driving Zone Filter Model — VSP Mobile App
//
// Filter contract for driving zone analytics queries.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
//
// Supports filtering by time range, club selection, tee set, and wind conditions.

import 'package:equatable/equatable.dart';

/// Wind direction or condition filter.
enum WindCondition {
  any,
  calm, // 0-5 mph
  light, // 6-12 mph
  moderate, // 13-19 mph
  windy, // 20+ mph
  headwind,
  tailwind,
  crosswindLeft,
  crosswindRight;

  static WindCondition fromString(String? value) {
    if (value == null) return WindCondition.any;
    final normalized = _normalize(value);
    return WindCondition.values.firstWhere(
      (e) => _normalize(e.name) == normalized,
      orElse: () => WindCondition.any,
    );
  }

  static String _normalize(String value) {
    return value.replaceAll('-', '').replaceAll('_', '').toLowerCase();
  }

  String toApiValue() {
    switch (this) {
      case WindCondition.any:
        return 'any';
      case WindCondition.calm:
        return 'calm';
      case WindCondition.light:
        return 'light';
      case WindCondition.moderate:
        return 'moderate';
      case WindCondition.windy:
        return 'windy';
      case WindCondition.headwind:
        return 'headwind';
      case WindCondition.tailwind:
        return 'tailwind';
      case WindCondition.crosswindLeft:
        return 'crosswind_left';
      case WindCondition.crosswindRight:
        return 'crosswind_right';
    }
  }
}

/// Time range for filtering analytics data.
class TimeRange extends Equatable {
  final DateTime? start;
  final DateTime? end;

  const TimeRange({this.start, this.end});

  /// Predefined last-30-days range.
  factory TimeRange.last30Days() {
    final now = DateTime.now();
    return TimeRange(start: now.subtract(const Duration(days: 30)), end: now);
  }

  /// Predefined last-90-days range.
  factory TimeRange.last90Days() {
    final now = DateTime.now();
    return TimeRange(start: now.subtract(const Duration(days: 90)), end: now);
  }

  /// Predefined year-to-date range.
  factory TimeRange.yearToDate() {
    final now = DateTime.now();
    return TimeRange(start: DateTime(now.year, 1, 1), end: now);
  }

  /// All-time range (no filtering).
  factory TimeRange.allTime() {
    return const TimeRange(start: null, end: null);
  }

  bool get isEmpty => start == null && end == null;

  @override
  List<Object?> get props => [start, end];

  Map<String, dynamic> toJson() => {
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
  };

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      start: json['start'] != null
          ? DateTime.parse(json['start'] as String)
          : null,
      end: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
    );
  }
}

/// Driving zone analytics filter.
///
/// Filters driving zone statistics by time range, clubs, tee set, and wind.
class DrivingZoneFilter extends Equatable {
  /// Player account ID (required for data isolation).
  final String playerId;

  /// Time range for filtering shots.
  final TimeRange timeRange;

  /// Club IDs to include (empty = all clubs).
  final List<String> clubIds;

  /// Tee set ID to filter by (null = all tee sets).
  final String? teeSetId;

  /// Wind condition filter.
  final WindCondition? windCondition;

  /// Minimum number of shots required for statistically meaningful data.
  final int minimumShotCount;

  const DrivingZoneFilter({
    required this.playerId,
    this.timeRange = const TimeRange(),
    this.clubIds = const [],
    this.teeSetId,
    this.windCondition,
    this.minimumShotCount = 5,
  });

  /// Default filter with all-time range.
  factory DrivingZoneFilter.defaultFilter({required String playerId}) {
    return DrivingZoneFilter(
      playerId: playerId,
      timeRange: TimeRange.allTime(),
      minimumShotCount: 5,
    );
  }

  DrivingZoneFilter copyWith({
    String? playerId,
    TimeRange? timeRange,
    List<String>? clubIds,
    String? teeSetId,
    WindCondition? windCondition,
    int? minimumShotCount,
    bool clearTeeSetId = false,
    bool clearWindCondition = false,
  }) {
    return DrivingZoneFilter(
      playerId: playerId ?? this.playerId,
      timeRange: timeRange ?? this.timeRange,
      clubIds: clubIds ?? this.clubIds,
      teeSetId: clearTeeSetId ? null : (teeSetId ?? this.teeSetId),
      windCondition: clearWindCondition
          ? null
          : (windCondition ?? this.windCondition),
      minimumShotCount: minimumShotCount ?? this.minimumShotCount,
    );
  }

  @override
  List<Object?> get props => [
    playerId,
    timeRange,
    clubIds,
    teeSetId,
    windCondition,
    minimumShotCount,
  ];

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'timeRange': timeRange.toJson(),
    'clubIds': clubIds,
    'teeSetId': teeSetId,
    'windCondition': windCondition?.toApiValue(),
    'minimumShotCount': minimumShotCount,
  };

  factory DrivingZoneFilter.fromJson(Map<String, dynamic> json) {
    return DrivingZoneFilter(
      playerId: json['playerId'] as String,
      timeRange: json['timeRange'] != null
          ? TimeRange.fromJson(json['timeRange'] as Map<String, dynamic>)
          : const TimeRange(),
      clubIds:
          (json['clubIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      teeSetId: json['teeSetId'] as String?,
      windCondition: WindCondition.fromString(json['windCondition'] as String?),
      minimumShotCount: (json['minimumShotCount'] as num?)?.toInt() ?? 5,
    );
  }
}
