// Data Freshness DTO — VSP Mobile App
//
// Data freshness metadata returned in every course search result.
// Mirrors DataFreshnessDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';

/// Verification status enum — reflects backend DataQualityMetadata verificationStatus.
enum VerificationStatus {
  verified('VERIFIED'),
  pendingReview('PENDING_REVIEW'),
  unverified('UNVERIFIED'),
  rejected('REJECTED');

  final String value;
  const VerificationStatus(this.value);

  static VerificationStatus fromString(String value) {
    return VerificationStatus.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => VerificationStatus.unverified,
    );
  }

  /// Human-readable display label.
  String get displayLabel {
    switch (this) {
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.pendingReview:
        return 'Pending Review';
      case VerificationStatus.unverified:
        return 'Unverified';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }

  /// True if this status represents authoritative/official data.
  bool get isOfficial => this == VerificationStatus.verified;
}

/// Data freshness metadata for a course data version.
///
/// Returned in every CourseSearchResult to surface:
/// - When the data was last published (publishedAt)
/// - Which version number is current (versionNumber)
/// - Who published it (publisher)
/// - The verification status (verificationStatus)
/// - When it was last verified (lastVerifiedAt)
class DataFreshness extends Equatable {
  final DateTime publishedAt;
  final int versionNumber;
  final String? publisher;
  final VerificationStatus verificationStatus;
  final DateTime? lastVerifiedAt;
  final DateTime? expiryDate;

  /// Raw accuracy class as the API names it, e.g. `D_UNVERIFIED_COMMUNITY`.
  ///
  /// Verification status on its own says a human looked at the row; it says
  /// nothing about how the coordinates were obtained. Both are needed before
  /// the app is entitled to call a course verified, so the class travels with
  /// the freshness block.
  final String? accuracyClass;

  const DataFreshness({
    required this.publishedAt,
    required this.versionNumber,
    this.publisher,
    required this.verificationStatus,
    this.lastVerifiedAt,
    this.expiryDate,
    this.accuracyClass,
  });

  /// Parse from API response JSON (DataFreshnessDto).
  factory DataFreshness.fromJson(Map<String, dynamic> json) {
    return DataFreshness(
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      versionNumber: (json['versionNumber'] as num).toInt(),
      publisher: json['publisher'] as String?,
      verificationStatus: VerificationStatus.fromString(
        json['verificationStatus'] as String? ?? 'UNVERIFIED',
      ),
      lastVerifiedAt: json['lastVerifiedAt'] != null
          ? DateTime.tryParse(json['lastVerifiedAt'] as String)
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
      accuracyClass: json['accuracyClass'] as String?,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'publishedAt': publishedAt.toIso8601String(),
    'versionNumber': versionNumber,
    if (publisher != null) 'publisher': publisher,
    'verificationStatus': verificationStatus.value,
    if (lastVerifiedAt != null)
      'lastVerifiedAt': lastVerifiedAt!.toIso8601String(),
    if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
    if (accuracyClass != null) 'accuracyClass': accuracyClass,
  };

  /// Days since this data was published.
  int get daysSincePublished {
    return DateTime.now().difference(publishedAt).inDays;
  }

  /// True if the data has an explicit expiryDate that has passed.
  bool get isExpired =>
      expiryDate != null && DateTime.now().isAfter(expiryDate!);

  /// True if the published data is considered stale.
  /// Checks explicit expiryDate first; falls back to >30 days since publish.
  bool get isStale {
    if (isExpired) return true;
    return daysSincePublished > 30;
  }

  /// True if the data has been verified by an authoritative source.
  bool get isVerified => verificationStatus.isOfficial;

  /// The verification status the golfer should actually be shown.
  ///
  /// A VERIFIED stamp on class-D community data is not a verified course — the
  /// stamp says a row was reviewed, the class says nobody surveyed anything.
  /// The badge shows the weaker of the two claims rather than the flattering
  /// one, and an absent class is treated as class D.
  VerificationStatus get effectiveVerificationStatus {
    if (verificationStatus != VerificationStatus.verified) {
      return verificationStatus;
    }
    // Parsed here rather than via AccuracyClass to keep this file free of a
    // cycle back to data_quality.dart. Anything absent or unrecognised is not
    // survey grade.
    final letter = accuracyClass?.toUpperCase().split('_').first;
    final isSurveyGrade = letter == 'A' || letter == 'B' || letter == 'C';
    return isSurveyGrade
        ? VerificationStatus.verified
        : VerificationStatus.unverified;
  }

  DataFreshness copyWith({
    DateTime? publishedAt,
    int? versionNumber,
    String? publisher,
    VerificationStatus? verificationStatus,
    DateTime? lastVerifiedAt,
    DateTime? expiryDate,
    String? accuracyClass,
  }) {
    return DataFreshness(
      publishedAt: publishedAt ?? this.publishedAt,
      versionNumber: versionNumber ?? this.versionNumber,
      publisher: publisher ?? this.publisher,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      accuracyClass: accuracyClass ?? this.accuracyClass,
    );
  }

  @override
  List<Object?> get props => [
    publishedAt,
    versionNumber,
    publisher,
    verificationStatus,
    lastVerifiedAt,
    expiryDate,
    accuracyClass,
  ];
}
