// FavoriteCourse and RecentCourse unit tests — VSP Mobile App
//
// Tests cover:
// - FavoriteCourse.fromJson parses all fields from API JSON
// - RecentCourse.fromJson parses all fields from API JSON
// - Serialization round-trip (toJson -> fromJson)
// - displayName computed helper
// - Relative time label helpers (favoritedAtLabel, viewedAtLabel)

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/favorite_course.dart';
import 'package:vsp_mobile/domain/models/recent_course.dart';

void main() {
  group('FavoriteCourse', () {
    group('fromJson', () {
      test('parses full FavoriteCourseDto response', () {
        final json = {
          'courseId': 123,
          'facilityId': 456,
          'facilityName': 'Saigon Golf Club',
          'courseName': ' Championship Course',
          'address': '123 Nguyen Hue, District 1, HCMC',
          'holesCount': 18,
          'favoritedAt': '2026-07-20T14:30:00Z',
        };

        final dto = FavoriteCourse.fromJson(json);

        expect(dto.courseId, 123);
        expect(dto.facilityId, 456);
        expect(dto.facilityName, 'Saigon Golf Club');
        expect(dto.courseName, ' Championship Course');
        expect(dto.address, '123 Nguyen Hue, District 1, HCMC');
        expect(dto.holesCount, 18);
        expect(dto.favoritedAt, DateTime.parse('2026-07-20T14:30:00Z'));
      });

      test('handles null optional fields', () {
        final json = {
          'courseId': 123,
          'facilityId': 456,
          'facilityName': 'Saigon Golf Club',
          'holesCount': 9,
          'favoritedAt': '2026-07-20T14:30:00Z',
        };

        final dto = FavoriteCourse.fromJson(json);

        expect(dto.courseName, isNull);
        expect(dto.address, isNull);
      });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all fields correctly', () {
        final dto = FavoriteCourse(
          courseId: 123,
          facilityId: 456,
          facilityName: 'Saigon Golf Club',
          courseName: ' Championship Course',
          address: '123 Nguyen Hue',
          holesCount: 18,
          favoritedAt: DateTime.parse('2026-07-20T14:30:00Z'),
        );

        final json = dto.toJson();
        final roundTrip = FavoriteCourse.fromJson(json);

        expect(roundTrip.courseId, dto.courseId);
        expect(roundTrip.facilityId, dto.facilityId);
        expect(roundTrip.facilityName, dto.facilityName);
        expect(roundTrip.courseName, dto.courseName);
        expect(roundTrip.address, dto.address);
        expect(roundTrip.holesCount, dto.holesCount);
        expect(roundTrip.favoritedAt, dto.favoritedAt);
      });
    });

    group('computed helpers', () {
      test('displayName prefers courseName over facilityName', () {
        final withCourseName = FavoriteCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Facility',
          courseName: 'Course',
          holesCount: 18,
          favoritedAt: DateTime.now(),
        );
        final withoutCourseName = FavoriteCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Facility Only',
          holesCount: 18,
          favoritedAt: DateTime.now(),
        );

        expect(withCourseName.displayName, 'Course');
        expect(withoutCourseName.displayName, 'Facility Only');
      });

      test('favoritedAtLabel returns relative time strings', () {
        final justNow = FavoriteCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          favoritedAt: DateTime.now(),
        );
        final minutesAgo = FavoriteCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          favoritedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
        final hoursAgo = FavoriteCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          favoritedAt: DateTime.now().subtract(const Duration(hours: 3)),
        );
        final daysAgo = FavoriteCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          favoritedAt: DateTime.now().subtract(const Duration(days: 2)),
        );
        final weeksAgo = FavoriteCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          favoritedAt: DateTime.now().subtract(const Duration(days: 10)),
        );

        expect(justNow.favoritedAtLabel, 'Just now');
        expect(minutesAgo.favoritedAtLabel, '5m ago');
        expect(hoursAgo.favoritedAtLabel, '3h ago');
        expect(daysAgo.favoritedAtLabel, '2d ago');
        expect(weeksAgo.favoritedAtLabel, contains('/')); // date format
      });
    });
  });

  group('RecentCourse', () {
    group('fromJson', () {
      test('parses full RecentCourseDto response', () {
        final json = {
          'courseId': 123,
          'facilityId': 456,
          'facilityName': 'Saigon Golf Club',
          'courseName': ' Championship Course',
          'address': '123 Nguyen Hue, District 1, HCMC',
          'holesCount': 18,
          'viewedAt': '2026-07-20T14:30:00Z',
        };

        final dto = RecentCourse.fromJson(json);

        expect(dto.courseId, 123);
        expect(dto.facilityId, 456);
        expect(dto.facilityName, 'Saigon Golf Club');
        expect(dto.courseName, ' Championship Course');
        expect(dto.address, '123 Nguyen Hue, District 1, HCMC');
        expect(dto.holesCount, 18);
        expect(dto.viewedAt, DateTime.parse('2026-07-20T14:30:00Z'));
      });

      test('handles null optional fields', () {
        final json = {
          'courseId': 123,
          'facilityId': 456,
          'facilityName': 'Saigon Golf Club',
          'holesCount': 9,
          'viewedAt': '2026-07-20T14:30:00Z',
        };

        final dto = RecentCourse.fromJson(json);

        expect(dto.courseName, isNull);
        expect(dto.address, isNull);
      });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all fields correctly', () {
        final dto = RecentCourse(
          courseId: 123,
          facilityId: 456,
          facilityName: 'Saigon Golf Club',
          courseName: ' Championship Course',
          address: '123 Nguyen Hue',
          holesCount: 18,
          viewedAt: DateTime.parse('2026-07-20T14:30:00Z'),
        );

        final json = dto.toJson();
        final roundTrip = RecentCourse.fromJson(json);

        expect(roundTrip.courseId, dto.courseId);
        expect(roundTrip.facilityId, dto.facilityId);
        expect(roundTrip.facilityName, dto.facilityName);
        expect(roundTrip.courseName, dto.courseName);
        expect(roundTrip.address, dto.address);
        expect(roundTrip.holesCount, dto.holesCount);
        expect(roundTrip.viewedAt, dto.viewedAt);
      });
    });

    group('computed helpers', () {
      test('displayName prefers courseName over facilityName', () {
        final withCourseName = RecentCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Facility',
          courseName: 'Course',
          holesCount: 18,
          viewedAt: DateTime.now(),
        );
        final withoutCourseName = RecentCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Facility Only',
          holesCount: 18,
          viewedAt: DateTime.now(),
        );

        expect(withCourseName.displayName, 'Course');
        expect(withoutCourseName.displayName, 'Facility Only');
      });

      test('viewedAtLabel returns relative time strings', () {
        final justNow = RecentCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          viewedAt: DateTime.now(),
        );
        final minutesAgo = RecentCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          viewedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        );
        final hoursAgo = RecentCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          viewedAt: DateTime.now().subtract(const Duration(hours: 5)),
        );
        final daysAgo = RecentCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          viewedAt: DateTime.now().subtract(const Duration(days: 3)),
        );
        final weeksAgo = RecentCourse(
          courseId: 1,
          facilityId: 1,
          facilityName: 'Test',
          holesCount: 18,
          viewedAt: DateTime.now().subtract(const Duration(days: 14)),
        );

        expect(justNow.viewedAtLabel, 'Just now');
        expect(minutesAgo.viewedAtLabel, '12m ago');
        expect(hoursAgo.viewedAtLabel, '5h ago');
        expect(daysAgo.viewedAtLabel, '3d ago');
        expect(weeksAgo.viewedAtLabel, contains('/')); // date format
      });
    });
  });
}
