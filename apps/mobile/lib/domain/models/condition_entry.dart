// Condition Entry DTO — VSP Mobile App
//
// Active course condition for course detail conditions section.
// Mirrors ConditionDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';

/// Course condition type.
enum ConditionType {
  pinPosition('PIN_POSITION'),
  greenSpeed('GREEN_SPEED'),
  courseCondition('COURSE_CONDITION'),
  bunkerCondition('BUNKER_CONDITION'),
  cartPath('CART_PATH'),
  localRule('LOCAL_RULE'),
  alert('ALERT');

  final String value;
  const ConditionType(this.value);

  static ConditionType fromString(String value) {
    return ConditionType.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => ConditionType.courseCondition,
    );
  }

  String get displayLabel {
    switch (this) {
      case ConditionType.pinPosition:
        return 'Pin Position';
      case ConditionType.greenSpeed:
        return 'Green Speed';
      case ConditionType.courseCondition:
        return 'Course Condition';
      case ConditionType.bunkerCondition:
        return 'Bunker Condition';
      case ConditionType.cartPath:
        return 'Cart Path';
      case ConditionType.localRule:
        return 'Local Rule';
      case ConditionType.alert:
        return 'Alert';
    }
  }
}

/// Condition severity level.
enum ConditionSeverity {
  info('INFO'),
  minor('MINOR'),
  moderate('MODERATE'),
  major('MAJOR');

  final String value;
  const ConditionSeverity(this.value);

  static ConditionSeverity fromString(String value) {
    return ConditionSeverity.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => ConditionSeverity.info,
    );
  }

  String get displayLabel {
    switch (this) {
      case ConditionSeverity.info:
        return 'Info';
      case ConditionSeverity.minor:
        return 'Minor';
      case ConditionSeverity.moderate:
        return 'Moderate';
      case ConditionSeverity.major:
        return 'Major';
    }
  }
}

/// Source of condition data — mirrors PinSource but for conditions.
enum ConditionSource {
  official('OFFICIAL'),
  estimated('ESTIMATED'),
  manual('MANUAL'),
  crowdSourced('CROWD_SOURCED');

  final String value;
  const ConditionSource(this.value);

  static ConditionSource fromString(String value) {
    return ConditionSource.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => ConditionSource.manual,
    );
  }

  String get displayLabel {
    switch (this) {
      case ConditionSource.official:
        return 'Official';
      case ConditionSource.estimated:
        return 'Estimated';
      case ConditionSource.manual:
        return 'Manual';
      case ConditionSource.crowdSourced:
        return 'Crowd-Sourced';
    }
  }
}

/// Active course condition entry.
class ConditionEntry extends Equatable {
  final ConditionType conditionType;
  final ConditionSeverity severity;
  final String? description;
  final DateTime? effectiveDate;
  final String accuracyClass;
  final ConditionSource? source;
  final double? confidence;
  final DateTime? expiryDate;

  const ConditionEntry({
    required this.conditionType,
    required this.severity,
    this.description,
    this.effectiveDate,
    required this.accuracyClass,
    this.source,
    this.confidence,
    this.expiryDate,
  });

  /// True when expiryDate is set and has passed.
  bool get isExpired =>
      expiryDate != null && DateTime.now().isAfter(expiryDate!);

  /// True when this condition comes from an authoritative/official source.
  bool get isOfficial => source == ConditionSource.official;

  factory ConditionEntry.fromJson(Map<String, dynamic> json) {
    return ConditionEntry(
      conditionType: ConditionType.fromString(
        json['conditionType'] as String? ?? 'COURSE_CONDITION',
      ),
      severity: ConditionSeverity.fromString(
        json['severity'] as String? ?? 'INFO',
      ),
      description: json['description'] as String?,
      effectiveDate: json['effectiveDate'] != null
          ? DateTime.tryParse(json['effectiveDate'] as String)
          : null,
      accuracyClass: json['accuracyClass'] as String? ?? 'D',
      source: json['source'] != null
          ? ConditionSource.fromString(json['source'] as String)
          : null,
      confidence: (json['confidence'] as num?)?.toDouble(),
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'conditionType': conditionType.value,
    'severity': severity.value,
    if (description != null) 'description': description,
    if (effectiveDate != null)
      'effectiveDate': effectiveDate!.toIso8601String(),
    'accuracyClass': accuracyClass,
    if (source != null) 'source': source!.value,
    if (confidence != null) 'confidence': confidence,
    if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
  };

  ConditionEntry copyWith({
    ConditionType? conditionType,
    ConditionSeverity? severity,
    String? description,
    DateTime? effectiveDate,
    String? accuracyClass,
    ConditionSource? source,
    double? confidence,
    DateTime? expiryDate,
  }) {
    return ConditionEntry(
      conditionType: conditionType ?? this.conditionType,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      accuracyClass: accuracyClass ?? this.accuracyClass,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  @override
  List<Object?> get props => [
    conditionType,
    severity,
    description,
    effectiveDate,
    accuracyClass,
    source,
    confidence,
    expiryDate,
  ];
}
