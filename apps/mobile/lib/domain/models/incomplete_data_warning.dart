// Incomplete Data Warning Model — VSP Mobile App
//
// Warning model for insufficient analytics sample size.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
//
// Surfaces when shot sample is too small for statistically meaningful
// analytics, preventing false precision claims per AC2.

import 'package:equatable/equatable.dart';

/// Severity level for the warning.
enum WarningSeverity {
  info,
  warning,
  error;

  static WarningSeverity fromString(String? value) {
    if (value == null) return WarningSeverity.info;
    return WarningSeverity.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WarningSeverity.info,
    );
  }
}

/// Category of data that is insufficient.
enum InsufficientDataCategory {
  totalShots,
  clubShots,
  holeShots,
  roundShots,
  timeRange,
  clubFilter,
  teeFilter,
  windFilter,
  mixed;

  static InsufficientDataCategory fromString(String? value) {
    if (value == null) return InsufficientDataCategory.totalShots;
    return InsufficientDataCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InsufficientDataCategory.totalShots,
    );
  }
}

/// A warning indicating that the underlying data is insufficient
/// for statistically meaningful analytics.
class IncompleteDataWarning extends Equatable {
  /// Unique identifier for this warning.
  final String id;

  /// Severity level of the warning.
  final WarningSeverity severity;

  /// Category of insufficient data.
  final InsufficientDataCategory category;

  /// Human-readable short title.
  final String title;

  /// Detailed explanation of the limitation.
  final String message;

  /// Minimum sample size required for reliability.
  final int requiredMinimum;

  /// Actual sample size available.
  final int actualCount;

  /// Recommended action to improve data quality.
  final String? recommendedAction;

  /// Timestamp when this warning was generated.
  final DateTime? generatedAt;

  /// The metric or filter context that triggered this warning.
  final String? context;

  const IncompleteDataWarning({
    required this.id,
    this.severity = WarningSeverity.warning,
    required this.category,
    required this.title,
    required this.message,
    required this.requiredMinimum,
    required this.actualCount,
    this.recommendedAction,
    required this.generatedAt,
    this.context,
  });

  /// Shortage ratio: how far the actual is from the required (0.0–1.0).
  double get shortageRatio {
    if (requiredMinimum == 0) return 1.0;
    return (requiredMinimum - actualCount).clamp(0, requiredMaximum) /
        requiredMaximum;
  }

  int get requiredMaximum => requiredMinimum;

  /// Whether this warning should block display of metrics.
  bool get isBlocking => severity == WarningSeverity.error;

  @override
  List<Object?> get props => [
    id,
    severity,
    category,
    title,
    message,
    requiredMinimum,
    actualCount,
    recommendedAction,
    generatedAt,
    context,
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'severity': severity.name,
    'category': category.name,
    'title': title,
    'message': message,
    'requiredMinimum': requiredMinimum,
    'actualCount': actualCount,
    'recommendedAction': recommendedAction,
    'generatedAt': generatedAt?.toIso8601String(),
    'context': context,
  };

  factory IncompleteDataWarning.fromJson(Map<String, dynamic> json) {
    return IncompleteDataWarning(
      id: json['id'] as String,
      severity: WarningSeverity.fromString(json['severity'] as String?),
      category: InsufficientDataCategory.fromString(
        json['category'] as String?,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      requiredMinimum: json['requiredMinimum'] as int,
      actualCount: json['actualCount'] as int,
      recommendedAction: json['recommendedAction'] as String?,
      generatedAt: json['generatedAt'] == null
          ? null
          : DateTime.parse(json['generatedAt'] as String),
      context: json['context'] as String?,
    );
  }

  /// Creates a standard warning for insufficient total shots.
  factory IncompleteDataWarning.forTotalShots({
    required int requiredMinimum,
    required int actualCount,
    required DateTime generatedAt,
  }) {
    return IncompleteDataWarning(
      id: 'insufficient-total-shots-${generatedAt.millisecondsSinceEpoch}',
      severity: actualCount == 0
          ? WarningSeverity.error
          : WarningSeverity.warning,
      category: InsufficientDataCategory.totalShots,
      title: 'Insufficient Shot Data',
      message:
          'Only $actualCount shot${actualCount == 1 ? '' : 's'} recorded. '
          'At least $requiredMinimum shots are needed for reliable analytics.',
      requiredMinimum: requiredMinimum,
      actualCount: actualCount,
      recommendedAction:
          'Record more shots to unlock driving zone and round analytics.',
      generatedAt: generatedAt,
    );
  }

  /// Creates a warning for insufficient club-specific shots.
  factory IncompleteDataWarning.forClubShots({
    required String clubId,
    required String clubName,
    required int requiredMinimum,
    required int actualCount,
    required DateTime generatedAt,
  }) {
    return IncompleteDataWarning(
      id: 'insufficient-club-shots-$clubId-${generatedAt.millisecondsSinceEpoch}',
      severity: actualCount == 0
          ? WarningSeverity.error
          : WarningSeverity.warning,
      category: InsufficientDataCategory.clubShots,
      title: 'Limited Club Data',
      message:
          '$clubName has only $actualCount recorded shot${actualCount == 1 ? '' : 's'}. '
          '$requiredMinimum shots recommended for accurate club analytics.',
      requiredMinimum: requiredMinimum,
      actualCount: actualCount,
      recommendedAction:
          'Use $clubName more often to build a reliable club profile.',
      generatedAt: generatedAt,
      context: clubId,
    );
  }

  /// Creates a warning for insufficient hole-specific shots.
  factory IncompleteDataWarning.forHoleShots({
    required int holeNumber,
    required int requiredMinimum,
    required int actualCount,
    required DateTime generatedAt,
  }) {
    return IncompleteDataWarning(
      id: 'insufficient-hole-shots-$holeNumber-${generatedAt.millisecondsSinceEpoch}',
      severity: actualCount == 0
          ? WarningSeverity.error
          : WarningSeverity.warning,
      category: InsufficientDataCategory.holeShots,
      title: 'Limited Hole Data',
      message:
          'Hole $holeNumber has only $actualCount recorded shot${actualCount == 1 ? '' : 's'}. '
          '$requiredMinimum shots recommended for hole-specific analytics.',
      requiredMinimum: requiredMinimum,
      actualCount: actualCount,
      recommendedAction:
          'Play hole $holeNumber more times to get personalized insights.',
      generatedAt: generatedAt,
      context: 'hole-$holeNumber',
    );
  }
}
