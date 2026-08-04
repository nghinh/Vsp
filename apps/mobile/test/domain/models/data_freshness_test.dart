// DataFreshness unit tests — VSP Mobile App
//
// Tests cover:
// - fromJson parses all fields from API JSON
// - toJson serialization round-trip
// - VerificationStatus enum parsing and display helpers
// - isStale, isVerified computed properties

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';

void main() {
  group('VerificationStatus', () {
    test('fromString handles known values case-insensitively', () {
      expect(VerificationStatus.fromString('VERIFIED'), VerificationStatus.verified);
      expect(VerificationStatus.fromString('verified'), VerificationStatus.verified);
      expect(VerificationStatus.fromString('PENDING_REVIEW'), VerificationStatus.pendingReview);
      expect(VerificationStatus.fromString('pending_review'), VerificationStatus.pendingReview);
      expect(VerificationStatus.fromString('UNVERIFIED'), VerificationStatus.unverified);
      expect(VerificationStatus.fromString('REJECTED'), VerificationStatus.rejected);
    });

    test('fromString defaults to unverified for unknown values', () {
      expect(VerificationStatus.fromString('UNKNOWN'), VerificationStatus.unverified);
      expect(VerificationStatus.fromString(''), VerificationStatus.unverified);
    });

    test('displayLabel returns human-readable labels', () {
      expect(VerificationStatus.verified.displayLabel, 'Verified');
      expect(VerificationStatus.pendingReview.displayLabel, 'Pending Review');
      expect(VerificationStatus.unverified.displayLabel, 'Unverified');
      expect(VerificationStatus.rejected.displayLabel, 'Rejected');
    });

    test('isOfficial is true only for verified', () {
      expect(VerificationStatus.verified.isOfficial, isTrue);
      expect(VerificationStatus.pendingReview.isOfficial, isFalse);
      expect(VerificationStatus.unverified.isOfficial, isFalse);
      expect(VerificationStatus.rejected.isOfficial, isFalse);
    });
  });

  group('DataFreshness', () {
    group('fromJson — all fields parsed', () {
      test('parses full DataFreshnessDto response', () {
        final json = {
          'publishedAt': '2026-07-15T10:00:00Z',
          'versionNumber': 3,
          'publisher': 'Thuyle Golf Club',
          'verificationStatus': 'VERIFIED',
          'lastVerifiedAt': '2026-07-14T08:30:00Z',
        };

        final dto = DataFreshness.fromJson(json);

        expect(dto.publishedAt, DateTime.parse('2026-07-15T10:00:00Z'));
        expect(dto.versionNumber, 3);
        expect(dto.publisher, 'Thuyle Golf Club');
        expect(dto.verificationStatus, VerificationStatus.verified);
        expect(dto.lastVerifiedAt, DateTime.parse('2026-07-14T08:30:00Z'));
      });

      test('handles null optional fields', () {
        final json = {
          'publishedAt': '2026-07-15T10:00:00Z',
          'versionNumber': 1,
          'verificationStatus': 'UNVERIFIED',
        };

        final dto = DataFreshness.fromJson(json);

        expect(dto.publisher, isNull);
        expect(dto.lastVerifiedAt, isNull);
      });

      test('defaults to unverified for null verificationStatus', () {
        final json = {
          'publishedAt': '2026-07-15T10:00:00Z',
          'versionNumber': 1,
        };

        final dto = DataFreshness.fromJson(json);

        expect(dto.verificationStatus, VerificationStatus.unverified);
      });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all fields correctly', () {
        final dto = DataFreshness(
          publishedAt: DateTime.parse('2026-07-15T10:00:00Z'),
          versionNumber: 3,
          publisher: 'Thuyle Golf Club',
          verificationStatus: VerificationStatus.verified,
          lastVerifiedAt: DateTime.parse('2026-07-14T08:30:00Z'),
        );

        final json = dto.toJson();
        final roundTrip = DataFreshness.fromJson(json);

        expect(roundTrip.publishedAt, dto.publishedAt);
        expect(roundTrip.versionNumber, dto.versionNumber);
        expect(roundTrip.publisher, dto.publisher);
        expect(roundTrip.verificationStatus, dto.verificationStatus);
        expect(roundTrip.lastVerifiedAt, dto.lastVerifiedAt);
      });

      test('omits null optional fields', () {
        final dto = DataFreshness(
          publishedAt: DateTime.parse('2026-07-15T10:00:00Z'),
          versionNumber: 1,
          verificationStatus: VerificationStatus.unverified,
        );

        final json = dto.toJson();

        expect(json.containsKey('publisher'), isFalse);
        expect(json.containsKey('lastVerifiedAt'), isFalse);
      });
    });

    group('computed properties', () {
      test('isVerified delegates to verificationStatus.isOfficial', () {
        final verified = DataFreshness(
          publishedAt: DateTime.now(),
          versionNumber: 1,
          verificationStatus: VerificationStatus.verified,
        );
        final unverified = DataFreshness(
          publishedAt: DateTime.now(),
          versionNumber: 1,
          verificationStatus: VerificationStatus.unverified,
        );

        expect(verified.isVerified, isTrue);
        expect(unverified.isVerified, isFalse);
      });

      test('isStale is true when published more than 30 days ago', () {
        final fresh = DataFreshness(
          publishedAt: DateTime.now().subtract(const Duration(days: 10)),
          versionNumber: 1,
          verificationStatus: VerificationStatus.verified,
        );
        final stale = DataFreshness(
          publishedAt: DateTime.now().subtract(const Duration(days: 31)),
          versionNumber: 1,
          verificationStatus: VerificationStatus.verified,
        );

        expect(fresh.isStale, isFalse);
        expect(stale.isStale, isTrue);
      });
    });
  });
}
