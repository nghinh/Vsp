// Data Quality Model — VSP Mobile App
//
// Extends DataFreshness with accuracy class for AC-3 data quality distinction.
// Mirrors DataFreshnessDto enriched with AccuracyClass from course.yaml.

import 'package:equatable/equatable.dart';

import 'data_freshness.dart';

/// Accuracy class enum — mirrors AccuracyClass from backend.
enum AccuracyClass {
  classA('A'),
  classB('B'),
  classC('C'),
  classD('D');

  final String value;
  const AccuracyClass(this.value);

  static AccuracyClass fromString(String value) {
    switch (value.toUpperCase()) {
      case 'A':
        return AccuracyClass.classA;
      case 'B':
        return AccuracyClass.classB;
      case 'C':
        return AccuracyClass.classC;
      case 'D':
      default:
        return AccuracyClass.classD;
    }
  }

  /// Human-readable label.
  String get label {
    switch (this) {
      case AccuracyClass.classA:
        return 'Class A';
      case AccuracyClass.classB:
        return 'Class B';
      case AccuracyClass.classC:
        return 'Class C';
      case AccuracyClass.classD:
        return 'Class D';
    }
  }

  /// True if this class is considered official (Class A or B).
  bool get isOfficial =>
      this == AccuracyClass.classA || this == AccuracyClass.classB;
}

/// Data quality badge variant — derived from accuracy class + verification status + staleness.
enum DataQualityVariant { official, estimated, community, stale }

/// Full data quality model — extends DataFreshness with accuracy class.
class DataQuality extends Equatable {
  final DateTime publishedAt;
  final int versionNumber;
  final String? publisher;
  final VerificationStatus verificationStatus;
  final DateTime? lastVerifiedAt;
  final AccuracyClass accuracyClass;

  const DataQuality({
    required this.publishedAt,
    required this.versionNumber,
    this.publisher,
    required this.verificationStatus,
    this.lastVerifiedAt,
    required this.accuracyClass,
  });

  /// Parse from API response JSON.
  factory DataQuality.fromJson(Map<String, dynamic> json) {
    return DataQuality(
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      versionNumber: json['versionNumber'] as int,
      publisher: json['publisher'] as String?,
      verificationStatus: VerificationStatus.fromString(
        json['verificationStatus'] as String? ?? 'UNVERIFIED',
      ),
      lastVerifiedAt: json['lastVerifiedAt'] != null
          ? DateTime.tryParse(json['lastVerifiedAt'] as String)
          : null,
      accuracyClass: AccuracyClass.fromString(
        json['accuracyClass'] as String? ?? 'D',
      ),
    );
  }

  /// Create from existing DataFreshness + accuracy class.
  factory DataQuality.fromDataFreshness(
    DataFreshness freshness,
    AccuracyClass accuracyClass,
  ) {
    return DataQuality(
      publishedAt: freshness.publishedAt,
      versionNumber: freshness.versionNumber,
      publisher: freshness.publisher,
      verificationStatus: freshness.verificationStatus,
      lastVerifiedAt: freshness.lastVerifiedAt,
      accuracyClass: accuracyClass,
    );
  }

  Map<String, dynamic> toJson() => {
    'publishedAt': publishedAt.toIso8601String(),
    'versionNumber': versionNumber,
    if (publisher != null) 'publisher': publisher,
    'verificationStatus': verificationStatus.value,
    if (lastVerifiedAt != null)
      'lastVerifiedAt': lastVerifiedAt!.toIso8601String(),
    'accuracyClass': accuracyClass.value,
  };

  /// Days since this data was published.
  int get daysSincePublished => DateTime.now().difference(publishedAt).inDays;

  /// True if the published data is considered stale (> 30 days since publish).
  bool get isStale => daysSincePublished > 30;

  /// True if the data has been verified by an authoritative source.
  bool get isVerified => verificationStatus.isOfficial;

  /// Resolved badge variant for UI rendering.
  ///
  /// Order of precedence:
  /// 1. stale (>30d) → stale variant
  /// 2. official (Class A/B + VERIFIED) → official variant
  /// 3. Class C → estimated variant
  /// 4. Class D → community variant
  DataQualityVariant get variant {
    if (isStale) return DataQualityVariant.stale;
    if (accuracyClass.isOfficial && isVerified)
      return DataQualityVariant.official;
    if (accuracyClass == AccuracyClass.classC)
      return DataQualityVariant.estimated;
    return DataQualityVariant.community;
  }

  @override
  List<Object?> get props => [
    publishedAt,
    versionNumber,
    publisher,
    verificationStatus,
    lastVerifiedAt,
    accuracyClass,
  ];
}
