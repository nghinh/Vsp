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

  /// Parses either the bare letter or the backend enum name.
  ///
  /// The API sends `AccuracyClass.name()` — `C_VERIFIED_SATELLITE`, not `C` —
  /// so matching only single letters silently downgraded every course to class
  /// D. Anything unrecognised still lands on class D: the app must never
  /// promote data it cannot identify.
  static AccuracyClass fromString(String value) {
    switch (value.toUpperCase().split('_').first) {
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
      versionNumber: (json['versionNumber'] as num).toInt(),
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

  /// True when the coordinates behind this data were obtained by survey,
  /// licence or satellite digitisation *and* a human confirmed it.
  ///
  /// Class alone is a claim about method; verification is the claim that
  /// somebody checked. Both are required, in that order, because the seeded
  /// demo data asserted class C on coordinates that were pure arithmetic.
  bool get isSurveyed => isVerified && accuracyClass != AccuracyClass.classD;

  /// Resolved badge variant for UI rendering.
  ///
  /// Order of precedence:
  /// 1. stale (>30d) → stale variant
  /// 2. official (Class A/B + VERIFIED) → official variant
  /// 3. Class C *and* VERIFIED → estimated variant
  /// 4. anything else → community variant
  ///
  /// "Estimated" used to be reached on class alone. A row could claim
  /// satellite accuracy, never have been verified by anyone, and still read as
  /// an estimate somebody had made — which is a stronger claim than the data
  /// supports. Unverified now falls through to community whatever the class.
  DataQualityVariant get variant {
    if (isStale) return DataQualityVariant.stale;
    if (accuracyClass.isOfficial && isVerified)
      return DataQualityVariant.official;
    if (accuracyClass == AccuracyClass.classC && isVerified)
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
