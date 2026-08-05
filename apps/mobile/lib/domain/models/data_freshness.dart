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

  const DataFreshness({
    required this.publishedAt,
    required this.versionNumber,
    this.publisher,
    required this.verificationStatus,
    this.lastVerifiedAt,
    this.expiryDate,
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

  DataFreshness copyWith({
    DateTime? publishedAt,
    int? versionNumber,
    String? publisher,
    VerificationStatus? verificationStatus,
    DateTime? lastVerifiedAt,
    DateTime? expiryDate,
  }) {
    return DataFreshness(
      publishedAt: publishedAt ?? this.publishedAt,
      versionNumber: versionNumber ?? this.versionNumber,
      publisher: publisher ?? this.publisher,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      expiryDate: expiryDate ?? this.expiryDate,
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
  ];
}
