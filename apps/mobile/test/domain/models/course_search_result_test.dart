// CourseSearchResult unit tests — VSP Mobile App
//
// Tests cover:
// - CourseSearchResult.fromJson parses all fields from API JSON
// - CourseSearchResult.toJson serialization round-trip
// - CourseSearchPage.fromJson paginated response parsing
// - displayName, formattedDistance, isVerified, isDataStale computed helpers
// - CourseSearchParams query parameter building

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/data/api/course_search_api.dart';

void main() {
  group('CourseSearchResult', () {
    group('fromJson — all fields parsed', () {
      test('parses full search result with DataFreshness', () {
        final json = {
          'courseId': 123,
          'facilityId': 456,
          'facilityName': 'Saigon Golf Club',
          'courseName': ' Championship Course',
          'address': '123 Nguyen Hue, District 1, HCMC',
          'latitude': 10.8231,
          'longitude': 106.6292,
          'holesCount': 18,
          'parTotal': 72,
          'rating': 4.5,
          'slope': 125,
          'distanceMeters': 1523.5,
          'hasPackage': true,
          'updateAvailable': false,
          'dataFreshness': {
            'publishedAt': '2026-07-15T10:00:00Z',
            'versionNumber': 3,
            'publisher': 'Thuyle Golf Club',
            'verificationStatus': 'VERIFIED',
            'lastVerifiedAt': '2026-07-14T08:30:00Z',
          },
        };

        final dto = CourseSearchResult.fromJson(json);

        expect(dto.courseId, 123);
        expect(dto.facilityId, 456);
        expect(dto.facilityName, 'Saigon Golf Club');
        expect(dto.courseName, ' Championship Course');
        expect(dto.address, '123 Nguyen Hue, District 1, HCMC');
        expect(dto.latitude, 10.8231);
        expect(dto.longitude, 106.6292);
        expect(dto.holesCount, 18);
        expect(dto.parTotal, 72);
        expect(dto.rating, 4.5);
        expect(dto.slope, 125);
        expect(dto.distanceMeters, 1523.5);
        expect(dto.hasPackage, isTrue);
        expect(dto.updateAvailable, isFalse);
        expect(dto.dataFreshness, isNotNull);
        expect(dto.dataFreshness!.versionNumber, 3);
        expect(dto.dataFreshness!.verificationStatus, VerificationStatus.verified);
      });

      test('handles null optional fields', () {
        final json = {
          'courseId': 123,
          'facilityId': 456,
          'facilityName': 'Saigon Golf Club',
          'latitude': 10.8231,
          'longitude': 106.6292,
          'holesCount': 18,
          'hasPackage': false,
          'updateAvailable': false,
        };

        final dto = CourseSearchResult.fromJson(json);

        expect(dto.courseName, isNull);
        expect(dto.address, isNull);
        expect(dto.parTotal, isNull);
        expect(dto.rating, isNull);
        expect(dto.slope, isNull);
        expect(dto.distanceMeters, isNull);
        expect(dto.dataFreshness, isNull);
      });

      test('defaults hasPackage and updateAvailable to false when null', () {
        final json = {
          'courseId': 123,
          'facilityId': 456,
          'facilityName': 'Test',
          'latitude': 10.0,
          'longitude': 106.0,
          'holesCount': 9,
        };

        final dto = CourseSearchResult.fromJson(json);

        expect(dto.hasPackage, isFalse);
        expect(dto.updateAvailable, isFalse);
      });
    test('an absent coordinate stays absent instead of becoming 0, 0', () {
      // A facility the roster knows by name but nobody has located yet comes
      // back without latitude/longitude. These used to default to 0.0, which
      // is not "unknown": it is a point in the Gulf of Guinea, 10,000 km from
      // any Vietnamese course, and nothing downstream could tell it from a
      // real answer.
      final dto = CourseSearchResult.fromJson(const {
        'courseId': 1,
        'facilityId': 2,
        'facilityName': 'Sân golf chưa có toạ độ',
        'holesCount': 18,
      });

      expect(dto.latitude, isNull);
      expect(dto.longitude, isNull);
    });

    test('a course with no coordinate does not serialise one', () {
      const dto = CourseSearchResult(
        courseId: 1,
        facilityId: 2,
        facilityName: 'Sân golf chưa có toạ độ',
        holesCount: 18,
        hasPackage: false,
        updateAvailable: false,
      );

      final json = dto.toJson();

      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
    });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all fields correctly', () {
        final dto = CourseSearchResult(
          courseId: 123,
          facilityId: 456,
          facilityName: 'Saigon Golf Club',
          courseName: ' Championship Course',
          address: '123 Nguyen Hue',
          latitude: 10.8231,
          longitude: 106.6292,
          holesCount: 18,
          parTotal: 72,
          rating: 4.5,
          slope: 125,
          distanceMeters: 1523.5,
          hasPackage: true,
          updateAvailable: false,
          dataFreshness: DataFreshness(
            publishedAt: DateTime.parse('2026-07-15T10:00:00Z'),
            versionNumber: 3,
            publisher: 'Thuyle Golf Club',
            verificationStatus: VerificationStatus.verified,
            lastVerifiedAt: DateTime.parse('2026-07-14T08:30:00Z'),
          ),
        );

        final json = dto.toJson();
        final roundTrip = CourseSearchResult.fromJson(json);

        expect(roundTrip.courseId, dto.courseId);
        expect(roundTrip.facilityId, dto.facilityId);
        expect(roundTrip.facilityName, dto.facilityName);
        expect(roundTrip.courseName, dto.courseName);
        expect(roundTrip.address, dto.address);
        expect(roundTrip.latitude, dto.latitude);
        expect(roundTrip.longitude, dto.longitude);
        expect(roundTrip.holesCount, dto.holesCount);
        expect(roundTrip.parTotal, dto.parTotal);
        expect(roundTrip.rating, dto.rating);
        expect(roundTrip.slope, dto.slope);
        expect(roundTrip.distanceMeters, dto.distanceMeters);
        expect(roundTrip.hasPackage, dto.hasPackage);
        expect(roundTrip.updateAvailable, dto.updateAvailable);
        expect(roundTrip.dataFreshness!.versionNumber, dto.dataFreshness!.versionNumber);
      });
    });

    group('computed helpers', () {
      test('displayName prefers courseName over facilityName', () {
        final withCourseName = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Facility',
          courseName: 'Course',
          latitude: 0, longitude: 0, holesCount: 18,
          hasPackage: false, updateAvailable: false,
        );
        final withoutCourseName = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Facility Only',
          latitude: 0, longitude: 0, holesCount: 18,
          hasPackage: false, updateAvailable: false,
        );

        expect(withCourseName.displayName, 'Course');
        expect(withoutCourseName.displayName, 'Facility Only');
      });

      test('formattedDistance formats meters and km correctly', () {
        final withMeters = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Test',
          latitude: 0, longitude: 0, holesCount: 18,
          distanceMeters: 523.0,
          hasPackage: false, updateAvailable: false,
        );
        final withKm = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Test',
          latitude: 0, longitude: 0, holesCount: 18,
          distanceMeters: 1523.5,
          hasPackage: false, updateAvailable: false,
        );
        final noDistance = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Test',
          latitude: 0, longitude: 0, holesCount: 18,
          hasPackage: false, updateAvailable: false,
        );

        expect(withMeters.formattedDistance, '523 m');
        expect(withKm.formattedDistance, '1.5 km');
        expect(noDistance.formattedDistance, '');
      });

      test('isVerified delegates to dataFreshness.isVerified', () {
        final verified = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Test',
          latitude: 0, longitude: 0, holesCount: 18,
          hasPackage: false, updateAvailable: false,
          dataFreshness: DataFreshness(
            publishedAt: DateTime.now(),
            versionNumber: 1,
            verificationStatus: VerificationStatus.verified,
          ),
        );
        final unverified = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Test',
          latitude: 0, longitude: 0, holesCount: 18,
          hasPackage: false, updateAvailable: false,
          dataFreshness: DataFreshness(
            publishedAt: DateTime.now(),
            versionNumber: 1,
            verificationStatus: VerificationStatus.unverified,
          ),
        );

        expect(verified.isVerified, isTrue);
        expect(unverified.isVerified, isFalse);
      });

      test('isDataStale delegates to dataFreshness.isStale', () {
        final fresh = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Test',
          latitude: 0, longitude: 0, holesCount: 18,
          hasPackage: false, updateAvailable: false,
          dataFreshness: DataFreshness(
            publishedAt: DateTime.now(),
            versionNumber: 1,
            verificationStatus: VerificationStatus.verified,
          ),
        );
        final stale = CourseSearchResult(
          courseId: 1, facilityId: 1,
          facilityName: 'Test',
          latitude: 0, longitude: 0, holesCount: 18,
          hasPackage: false, updateAvailable: false,
          dataFreshness: DataFreshness(
            publishedAt: DateTime.now().subtract(const Duration(days: 31)),
            versionNumber: 1,
            verificationStatus: VerificationStatus.verified,
          ),
        );

        expect(fresh.isDataStale, isFalse);
        expect(stale.isDataStale, isTrue);
      });
    });
  });

  group('CourseSearchPage', () {
    test('fromJson parses paginated response', () {
      final json = {
        'content': [
          {
            'courseId': 1,
            'facilityId': 1,
            'facilityName': 'Course A',
            'latitude': 10.0,
            'longitude': 106.0,
            'holesCount': 18,
            'hasPackage': true,
            'updateAvailable': false,
          },
        ],
        'page': 0,
        'size': 20,
        'totalElements': 1,
        'totalPages': 1,
        'first': true,
        'last': true,
      };

      final page = CourseSearchPage.fromJson(json);

      expect(page.content.length, 1);
      expect(page.content[0].facilityName, 'Course A');
      expect(page.page, 0);
      expect(page.size, 20);
      expect(page.totalElements, 1);
      expect(page.totalPages, 1);
      expect(page.first, isTrue);
      expect(page.last, isTrue);
    });

    test('hasNext and hasPrevious computed correctly', () {
      final firstPage = CourseSearchPage(
        content: [],
        page: 0,
        size: 20,
        totalElements: 50,
        totalPages: 3,
        first: true,
        last: false,
      );
      final middlePage = CourseSearchPage(
        content: [],
        page: 1,
        size: 20,
        totalElements: 50,
        totalPages: 3,
        first: false,
        last: false,
      );
      final lastPage = CourseSearchPage(
        content: [],
        page: 2,
        size: 20,
        totalElements: 50,
        totalPages: 3,
        first: false,
        last: true,
      );

      expect(firstPage.hasNext, isTrue);
      expect(firstPage.hasPrevious, isFalse);
      expect(middlePage.hasNext, isTrue);
      expect(middlePage.hasPrevious, isTrue);
      expect(lastPage.hasNext, isFalse);
      expect(lastPage.hasPrevious, isTrue);
    });
  });

  group('CourseSearchParams', () {
    test('toQueryParams builds all fields', () {
      const params = CourseSearchParams(
        query: 'Saigon Golf',
        latitude: 10.8231,
        longitude: 106.6292,
        radiusMeters: 10000.0,
        page: 2,
        size: 10,
        downloadedVersion: 3,
      );

      final qp = params.toQueryParams();

      expect(qp['q'], 'Saigon Golf');
      expect(qp['lat'], '10.8231');
      expect(qp['lng'], '106.6292');
      expect(qp['radiusMeters'], '10000.0');
      expect(qp['page'], '2');
      expect(qp['size'], '10');
      expect(qp['downloadedVersion'], '3');
    });

    test('toQueryParams omits null fields', () {
      const params = CourseSearchParams(
        query: 'Golf',
        page: 0,
        size: 20,
      );

      final qp = params.toQueryParams();

      expect(qp.containsKey('lat'), isFalse);
      expect(qp.containsKey('lng'), isFalse);
      expect(qp.containsKey('radius'), isFalse);
      expect(qp.containsKey('downloadedVersion'), isFalse);
    });

    test('toQueryParams omits empty query string', () {
      const params = CourseSearchParams(
        query: '',
        page: 0,
        size: 20,
      );

      final qp = params.toQueryParams();

      expect(qp.containsKey('q'), isFalse);
    });

    test('isNearbySearch returns true when lat/lng provided', () {
      const withCoords = CourseSearchParams(
        latitude: 10.0,
        longitude: 106.0,
        page: 0,
        size: 20,
      );
      const withoutCoords = CourseSearchParams(
        query: 'Golf',
        page: 0,
        size: 20,
      );

      expect(withCoords.isNearbySearch, isTrue);
      expect(withoutCoords.isNearbySearch, isFalse);
    });
  });
}
