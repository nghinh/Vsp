// A synthetic hole must be presented as unverified everywhere a distance
// derived from it is shown.
//
// The database this app ships against generated 831 of its 900 holes
// arithmetically — the green placed exactly `playing_length_meters` due north
// of a tee that was the clubhouse pin nudged along a fixed diagonal — and then
// stamped those rows C_VERIFIED_SATELLITE / VERIFIED / confidence 95. Every
// distance the app shows is measured between those two points, and a golfer
// picks a club from the distance.
//
// These tests pin the rule at every layer that stands between the label in the
// database and the number on the screen. They are deliberately about the
// *unhappy* path: each one describes a place the app used to say nothing.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart';
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/domain/models/hole_summary.dart';

void main() {
  group('accuracy class parsing', () {
    test('reads the backend enum name, not just a bare letter', () {
      // The API sends AccuracyClass.name(). Matching only 'A'..'D' silently
      // downgraded every course to class D, which made the quality badge
      // incapable of ever reporting anything else.
      expect(
        AccuracyClass.fromString('C_VERIFIED_SATELLITE'),
        AccuracyClass.classC,
      );
      expect(AccuracyClass.fromString('A_RTK_SURVEYED'), AccuracyClass.classA);
      expect(
        AccuracyClass.fromString('D_UNVERIFIED_COMMUNITY'),
        AccuracyClass.classD,
      );
      expect(AccuracyClass.fromString('C'), AccuracyClass.classC);
    });

    test('anything unrecognised is class D, never a promotion', () {
      expect(AccuracyClass.fromString(''), AccuracyClass.classD);
      expect(AccuracyClass.fromString('surveyed'), AccuracyClass.classD);
      expect(AccuracyClass.fromString('EXCELLENT'), AccuracyClass.classD);
    });
  });

  group('HoleDataProvenance', () {
    test('a hole that says nothing is not surveyed', () {
      expect(HoleDataProvenance.fromJson(null), HoleDataProvenance.unknown);
      expect(HoleDataProvenance.unknown.isSurveyed, isFalse);
      expect(HoleDataProvenance.fromJson(const {}).isSurveyed, isFalse);
    });

    test('the relabelled seed rows are not surveyed', () {
      final seeded = HoleDataProvenance.fromJson(const {
        'accuracyClass': 'D_UNVERIFIED_COMMUNITY',
        'verificationStatus': 'UNVERIFIED',
        'source': 'synthetic:seed-arithmetic',
      });

      expect(seeded.isSurveyed, isFalse);
    });

    test('the rows as they were mislabelled would have read as surveyed', () {
      // This is the whole point. The labels were the only thing wrong, and
      // with the old labels every gate in the app would have passed.
      final asShipped = HoleDataProvenance.fromJson(const {
        'accuracyClass': 'C_VERIFIED_SATELLITE',
        'verificationStatus': 'VERIFIED',
        'source': 'SEED',
      });

      expect(asShipped.isSurveyed, isTrue);
    });

    test('OpenStreetMap holes await review, so they are not surveyed', () {
      final osm = HoleDataProvenance.fromJson(const {
        'accuracyClass': 'D_UNVERIFIED_COMMUNITY',
        'verificationStatus': 'PENDING_REVIEW',
        'source': 'osm:way/1017320363',
      });

      expect(osm.isSurveyed, isFalse);
    });

    test('class alone is not enough — an unverified class C is not surveyed',
        () {
      const claimedButUnchecked = HoleDataProvenance(
        accuracyClass: AccuracyClass.classC,
        verificationStatus: VerificationStatus.unverified,
      );

      expect(claimedButUnchecked.isSurveyed, isFalse);
    });
  });

  group('HoleSummary — the length on the course detail scorecard', () {
    test('carries its hole\'s provenance and reports it unverified', () {
      final hole = HoleSummary.fromJson(const {
        'holeNumber': 2,
        'par': 5,
        'playingLengthMeters': 377.1,
        'dataQuality': {
          'accuracyClass': 'D_UNVERIFIED_COMMUNITY',
          'verificationStatus': 'UNVERIFIED',
        },
      });

      expect(hole.playingLengthMeters, 377);
      expect(hole.isSurveyed, isFalse);
    });

    test('a payload with no dataQuality block is not surveyed', () {
      // An older API, a cached response, a hand-written fixture — all of them
      // land here, and none of them is evidence that anybody surveyed a hole.
      final hole = HoleSummary.fromJson(const {
        'holeNumber': 1,
        'par': 4,
        'playingLengthMeters': 362.0,
      });

      expect(hole.isSurveyed, isFalse);
    });

    test('a verified class C hole is allowed to be surveyed', () {
      final hole = HoleSummary.fromJson(const {
        'holeNumber': 1,
        'par': 4,
        'playingLengthMeters': 362.0,
        'dataQuality': {
          'accuracyClass': 'C_VERIFIED_SATELLITE',
          'verificationStatus': 'VERIFIED',
        },
      });

      expect(hole.isSurveyed, isTrue);
    });
  });

  group('DataFreshness — the badge on a search result', () {
    DataFreshness freshness({
      required String verificationStatus,
      String? accuracyClass,
    }) {
      return DataFreshness.fromJson({
        'publishedAt': DateTime.now().toIso8601String(),
        'versionNumber': 1,
        'publisher': 'VSP Seed (synthetic)',
        'verificationStatus': verificationStatus,
        if (accuracyClass != null) 'accuracyClass': accuracyClass,
      });
    }

    test('a VERIFIED stamp on class D data does not read as verified', () {
      // The seeded data_versions row said PUBLISHED / VERIFIED for all 50
      // courses. Verification says a row was reviewed; it says nothing about
      // how the coordinates were obtained.
      final subject = freshness(
        verificationStatus: 'VERIFIED',
        accuracyClass: 'D_UNVERIFIED_COMMUNITY',
      );

      expect(subject.verificationStatus, VerificationStatus.verified);
      expect(
        subject.effectiveVerificationStatus,
        VerificationStatus.unverified,
      );
    });

    test('a VERIFIED stamp with no class at all does not read as verified', () {
      final subject = freshness(verificationStatus: 'VERIFIED');

      expect(
        subject.effectiveVerificationStatus,
        VerificationStatus.unverified,
      );
    });

    test('a verified class C course still reads as verified', () {
      final subject = freshness(
        verificationStatus: 'VERIFIED',
        accuracyClass: 'C_VERIFIED_SATELLITE',
      );

      expect(subject.effectiveVerificationStatus, VerificationStatus.verified);
    });

    test('a weaker status is never strengthened by a good class', () {
      final subject = freshness(
        verificationStatus: 'PENDING_REVIEW',
        accuracyClass: 'A_RTK_SURVEYED',
      );

      expect(
        subject.effectiveVerificationStatus,
        VerificationStatus.pendingReview,
      );
    });
  });

  group('DataQuality — the badge on course detail', () {
    DataQuality quality(AccuracyClass accuracyClass, VerificationStatus status) {
      return DataQuality(
        publishedAt: DateTime.now(),
        versionNumber: 1,
        verificationStatus: status,
        accuracyClass: accuracyClass,
      );
    }

    test('class C that nobody verified is community, not estimated', () {
      // "Estimated" claims somebody made an estimate. Unverified class C is a
      // claim about method with nothing behind it.
      expect(
        quality(AccuracyClass.classC, VerificationStatus.unverified).variant,
        DataQualityVariant.community,
      );
      expect(
        quality(AccuracyClass.classC, VerificationStatus.pendingReview).variant,
        DataQualityVariant.community,
      );
    });

    test('verified class C is estimated', () {
      expect(
        quality(AccuracyClass.classC, VerificationStatus.verified).variant,
        DataQualityVariant.estimated,
      );
    });

    test('only a verified class A or B is official', () {
      expect(
        quality(AccuracyClass.classA, VerificationStatus.verified).variant,
        DataQualityVariant.official,
      );
      expect(
        quality(AccuracyClass.classA, VerificationStatus.unverified).variant,
        DataQualityVariant.community,
      );
    });

    test('isSurveyed needs both the class and the verification', () {
      expect(
        quality(AccuracyClass.classD, VerificationStatus.verified).isSurveyed,
        isFalse,
      );
      expect(
        quality(AccuracyClass.classC, VerificationStatus.unverified).isSurveyed,
        isFalse,
      );
      expect(
        quality(AccuracyClass.classC, VerificationStatus.verified).isSurveyed,
        isTrue,
      );
    });
  });
}
