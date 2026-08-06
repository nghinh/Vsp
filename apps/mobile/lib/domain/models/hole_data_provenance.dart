// Hole Data Provenance — VSP Mobile App
//
// Where a single hole's tee and green coordinates came from.
//
// This matters more than it looks. Every distance the app shows a golfer —
// the length on the scorecard, the yardage in the hole header, the metres to
// the green — is computed from those two points, and a golfer picks a club
// from the number. Most of the holes in the database were generated
// arithmetically for a demo: the green placed exactly `playing_length_meters`
// due north of a tee that was itself the clubhouse pin nudged along a fixed
// diagonal. Those rows once claimed C_VERIFIED_SATELLITE / VERIFIED.
//
// Provenance is per hole, not per course: a course can hold sixteen digitised
// holes and two the seed invented.

import 'package:equatable/equatable.dart';

import 'data_freshness.dart';
import 'data_quality.dart';

/// Accuracy class + verification status for one hole's coordinates.
class HoleDataProvenance extends Equatable {
  final AccuracyClass accuracyClass;
  final VerificationStatus verificationStatus;

  /// Free-form origin string from the backend, e.g. `synthetic:seed-arithmetic`,
  /// `osm:way/1017320363`. Kept for diagnostics; the UI decides on the two
  /// fields above, never on this.
  final String? source;

  const HoleDataProvenance({
    required this.accuracyClass,
    required this.verificationStatus,
    this.source,
  });

  /// What to assume when a hole says nothing about where its points came from.
  ///
  /// Fail closed. Silence is not a survey, and an absent field is exactly the
  /// case where the app has least reason to be confident.
  static const HoleDataProvenance unknown = HoleDataProvenance(
    accuracyClass: AccuracyClass.classD,
    verificationStatus: VerificationStatus.unverified,
  );

  /// Parses the API's `dataQuality` object. A null object is [unknown].
  factory HoleDataProvenance.fromJson(Map<String, dynamic>? json) {
    if (json == null) return unknown;
    return HoleDataProvenance(
      accuracyClass: AccuracyClass.fromString(
        json['accuracyClass'] as String? ?? 'D_UNVERIFIED_COMMUNITY',
      ),
      verificationStatus: VerificationStatus.fromString(
        json['verificationStatus'] as String? ?? 'UNVERIFIED',
      ),
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'accuracyClass': accuracyClass.value,
    'verificationStatus': verificationStatus.value,
    if (source != null) 'source': source,
  };

  /// True only for coordinates obtained by survey, licence or satellite
  /// digitisation (classes A, B, C) *that somebody then verified*.
  ///
  /// Class is a claim about method; verification is the claim that it was
  /// checked. Both are needed — the fabricated seed rows asserted class C.
  bool get isSurveyed =>
      verificationStatus == VerificationStatus.verified &&
      accuracyClass != AccuracyClass.classD;

  @override
  List<Object?> get props => [accuracyClass, verificationStatus, source];
}
