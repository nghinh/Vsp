// Course Detail Model Tests — VSP Mobile App

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/course_detail.dart';
import 'package:vsp_mobile/domain/models/hole_summary.dart';
import 'package:vsp_mobile/domain/models/tee_set_summary.dart';
import 'package:vsp_mobile/domain/models/condition_entry.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart';

void main() {
  group('CourseDetail', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'courseId': 1,
        'facilityId': 10,
        'facilityName': 'Kings Island Golf',
        'phone': '+84-24-1234-5678',
        'website': 'https://kingsislandgolf.vn',
        'address': 'Kings Island, Hanoi, Vietnam',
        'latitude': 21.0285,
        'longitude': 105.8542,
        'holesCount': 18,
        'parTotal': 72,
        'rating': 72.3,
        'slope': 125,
        'imageUrls': ['https://example.com/img1.jpg'],
        'facilities': ['Clubhouse', 'Restaurant', 'Pro Shop'],
        'localRules': ['Local Rule 1', 'Local Rule 2'],
        'holes': [
          {'holeNumber': 1, 'par': 4, 'playingLengthMeters': 380},
          {'holeNumber': 2, 'par': 5, 'playingLengthMeters': 510},
        ],
        'teeSets': [
          {
            'id': 1,
            'name': 'Championship',
            'gender': 'M',
            'totalPar': 72,
            'yardages': {'Forward': 6200, 'Back': 6500},
            'rating': 72.1,
            'slope': 124,
            'accuracyClass': 'A',
          },
        ],
        'conditions': [
          {
            'conditionType': 'GREEN_SPEED',
            'severity': 'INFO',
            'description': 'Green speed 9.5',
            'effectiveDate': '2026-08-01',
            'accuracyClass': 'A',
          },
        ],
        'dataFreshness': {
          'publishedAt': '2026-07-01T00:00:00.000Z',
          'versionNumber': 5,
          'publisher': 'Course Admin',
          'verificationStatus': 'VERIFIED',
          'lastVerifiedAt': '2026-07-15T00:00:00.000Z',
        },
        'accuracyClass': 'A',
      };

      final detail = CourseDetail.fromJson(json);

      expect(detail.courseId, 1);
      expect(detail.facilityId, 10);
      expect(detail.facilityName, 'Kings Island Golf');
      expect(detail.phone, '+84-24-1234-5678');
      expect(detail.website, 'https://kingsislandgolf.vn');
      expect(detail.address, 'Kings Island, Hanoi, Vietnam');
      expect(detail.latitude, 21.0285);
      expect(detail.longitude, 105.8542);
      expect(detail.holesCount, 18);
      expect(detail.parTotal, 72);
      expect(detail.rating, 72.3);
      expect(detail.slope, 125);
      expect(detail.imageUrls, ['https://example.com/img1.jpg']);
      expect(detail.facilities, ['Clubhouse', 'Restaurant', 'Pro Shop']);
      expect(detail.localRules, ['Local Rule 1', 'Local Rule 2']);
      expect(detail.holes.length, 2);
      expect(detail.holes[0].holeNumber, 1);
      expect(detail.holes[0].par, 4);
      expect(detail.holes[0].playingLengthMeters, 380);
      expect(detail.teeSets.length, 1);
      expect(detail.teeSets[0].name, 'Championship');
      expect(detail.conditions.length, 1);
      expect(detail.conditions[0].conditionType, ConditionType.greenSpeed);
      expect(detail.conditions[0].severity, ConditionSeverity.info);
      expect(detail.dataFreshness, isNotNull);
      expect(detail.dataFreshness!.verificationStatus, VerificationStatus.verified);
      expect(detail.accuracyClass, AccuracyClass.classA);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'courseId': 2,
        'facilityId': 20,
        'facilityName': 'Minimal Course',
        'latitude': 21.0,
        'longitude': 105.0,
        'holesCount': 9,
        'imageUrls': null,
        'facilities': null,
        'localRules': null,
        'holes': null,
        'teeSets': null,
        'conditions': null,
        'dataFreshness': null,
        'accuracyClass': null,
      };

      final detail = CourseDetail.fromJson(json);

      expect(detail.courseId, 2);
      expect(detail.phone, isNull);
      expect(detail.website, isNull);
      expect(detail.rating, isNull);
      expect(detail.imageUrls, isEmpty);
      expect(detail.facilities, isEmpty);
      expect(detail.localRules, isEmpty);
      expect(detail.holes, isEmpty);
      expect(detail.teeSets, isEmpty);
      expect(detail.conditions, isEmpty);
      expect(detail.dataFreshness, isNull);
      expect(detail.accuracyClass, isNull);
    });

    test('hasContact returns true only when contact info available', () {
      final withPhone = CourseDetail.fromJson({
        'courseId': 1, 'facilityId': 1, 'facilityName': 'Test',
        'latitude': 0, 'longitude': 0, 'holesCount': 9,
        'phone': '+84-123', 'imageUrls': [], 'facilities': [],
        'localRules': [], 'holes': [], 'teeSets': [], 'conditions': [],
      });
      expect(withPhone.hasContact, true);

      final withoutContact = CourseDetail.fromJson({
        'courseId': 1, 'facilityId': 1, 'facilityName': 'Test',
        'latitude': 0, 'longitude': 0, 'holesCount': 9,
        'imageUrls': [], 'facilities': [], 'localRules': [],
        'holes': [], 'teeSets': [], 'conditions': [],
      });
      expect(withoutContact.hasContact, false);
    });

    test('formattedCoordinates returns lat,lng string', () {
      final detail = CourseDetail.fromJson({
        'courseId': 1, 'facilityId': 1, 'facilityName': 'Test',
        'latitude': 21.02851, 'longitude': 105.85421, 'holesCount': 9,
        'imageUrls': [], 'facilities': [], 'localRules': [],
        'holes': [], 'teeSets': [], 'conditions': [],
      });
      expect(detail.formattedCoordinates, '21.02851, 105.85421');
    });

    test('dataQuality returns DataQuality when freshness available', () {
      final detail = CourseDetail.fromJson({
        'courseId': 1, 'facilityId': 1, 'facilityName': 'Test',
        'latitude': 0, 'longitude': 0, 'holesCount': 9,
        'imageUrls': [], 'facilities': [], 'localRules': [],
        'holes': [], 'teeSets': [], 'conditions': [],
        'dataFreshness': {
          // Recent publish (relative to now) so the data is not flagged stale.
          'publishedAt':
              DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
          'versionNumber': 3,
          'verificationStatus': 'VERIFIED',
        },
        'accuracyClass': 'A',
      });

      expect(detail.dataQuality, isNotNull);
      expect(detail.dataQuality!.accuracyClass, AccuracyClass.classA);
      expect(detail.dataQuality!.variant, DataQualityVariant.official);
    });

    test('dataQuality returns null when freshness is null', () {
      final detail = CourseDetail.fromJson({
        'courseId': 1, 'facilityId': 1, 'facilityName': 'Test',
        'latitude': 0, 'longitude': 0, 'holesCount': 9,
        'imageUrls': [], 'facilities': [], 'localRules': [],
        'holes': [], 'teeSets': [], 'conditions': [],
      });
      expect(detail.dataQuality, isNull);
    });
  });

  group('FacilityCourse', () {
    test('reads playable off the wire', () {
      final duong = FacilityCourse.fromJson({
        'courseId': 21, 'name': 'Đường A', 'holesCount': 9,
        'parTotal': 36, 'playable': false,
      });

      // holesCount says nine either way — the club really does have nine — so
      // this flag is the only thing separating an đường with a card behind it
      // from one that is a name and nothing else.
      expect(duong.holesCount, 9);
      expect(duong.playable, isFalse);
    });

    test('an older server that omits it is read as playable', () {
      // The field arrived after the phones did. Reading its absence as "not
      // playable" would empty the round-setup picker at every club at once,
      // which is a worse failure than the one the flag exists to prevent.
      final duong = FacilityCourse.fromJson({
        'courseId': 21, 'name': 'Đường A', 'holesCount': 9,
      });

      expect(duong.playable, isTrue);
    });
  });

  group('HoleSummary', () {
    test('fromJson parses fields correctly', () {
      final json = {'holeNumber': 5, 'par': 3, 'playingLengthMeters': 150};
      final hole = HoleSummary.fromJson(json);
      expect(hole.holeNumber, 5);
      expect(hole.par, 3);
      expect(hole.playingLengthMeters, 150);
      expect(hole.formattedLength, '150m');
    });

    test('fromJson handles null playingLengthMeters', () {
      final json = {'holeNumber': 5, 'par': 3};
      final hole = HoleSummary.fromJson(json);
      expect(hole.playingLengthMeters, isNull);
      expect(hole.formattedLength, isNull);
    });
  });

  group('TeeSetSummary', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 1,
        'name': 'Blue',
        'gender': 'M',
        'totalPar': 72,
        'yardages': {'Forward': 6000, 'Back': 6300},
        'rating': 71.2,
        'slope': 120,
        'accuracyClass': 'B',
      };
      final teeSet = TeeSetSummary.fromJson(json);
      expect(teeSet.id, 1);
      expect(teeSet.name, 'Blue');
      expect(teeSet.gender, 'M');
      expect(teeSet.genderLabel, 'Men');
      expect(teeSet.totalPar, 72);
      expect(teeSet.yardages, {'Forward': 6000, 'Back': 6300});
      expect(teeSet.rating, 71.2);
      expect(teeSet.slope, 120);
      expect(teeSet.accuracyClass, 'B');
    });

    test('genderLabel returns null for unknown gender', () {
      final teeSet = TeeSetSummary.fromJson({
        'id': 1, 'name': 'Test', 'gender': 'X',
        'totalPar': 72, 'yardages': {}, 'accuracyClass': 'D',
      });
      expect(teeSet.genderLabel, isNull);
    });
  });

  group('ConditionEntry', () {
    test('fromJson parses all condition types', () {
      final json = {
        'conditionType': 'GREEN_SPEED',
        'severity': 'MODERATE',
        'description': 'Fast greens',
        'effectiveDate': '2026-08-01',
        'accuracyClass': 'A',
      };
      final condition = ConditionEntry.fromJson(json);
      expect(condition.conditionType, ConditionType.greenSpeed);
      expect(condition.severity, ConditionSeverity.moderate);
      expect(condition.description, 'Fast greens');
    });

    test('ConditionType displayLabel is correct', () {
      expect(ConditionType.greenSpeed.displayLabel, 'Green Speed');
      expect(ConditionType.pinPosition.displayLabel, 'Pin Position');
      expect(ConditionType.alert.displayLabel, 'Alert');
    });

    test('ConditionSeverity displayLabel is correct', () {
      expect(ConditionSeverity.info.displayLabel, 'Info');
      expect(ConditionSeverity.moderate.displayLabel, 'Moderate');
      expect(ConditionSeverity.major.displayLabel, 'Major');
    });
  });

  group('DataQuality', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'publishedAt': '2026-07-01T00:00:00.000Z',
        'versionNumber': 5,
        'publisher': 'Admin',
        'verificationStatus': 'VERIFIED',
        'lastVerifiedAt': '2026-07-15T00:00:00.000Z',
        'accuracyClass': 'A',
      };
      final dq = DataQuality.fromJson(json);
      expect(dq.versionNumber, 5);
      expect(dq.publisher, 'Admin');
      expect(dq.verificationStatus, VerificationStatus.verified);
      expect(dq.accuracyClass, AccuracyClass.classA);
    });

    test('variant returns official for Class A/B + verified', () {
      final dq = DataQuality.fromJson({
        'publishedAt': '2026-08-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'A',
      });
      expect(dq.variant, DataQualityVariant.official);
    });

    test('variant returns estimated for Class C', () {
      final dq = DataQuality.fromJson({
        'publishedAt': '2026-08-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'C',
      });
      expect(dq.variant, DataQualityVariant.estimated);
    });

    test('variant returns community for Class D', () {
      final dq = DataQuality.fromJson({
        'publishedAt': '2026-08-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'D',
      });
      expect(dq.variant, DataQualityVariant.community);
    });

    test('variant returns stale when isStale is true', () {
      final dq = DataQuality.fromJson({
        'publishedAt': '2025-01-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'A',
      });
      expect(dq.isStale, true);
      expect(dq.variant, DataQualityVariant.stale);
    });

    test('AccuracyClass isOfficial returns true for A and B', () {
      expect(AccuracyClass.classA.isOfficial, true);
      expect(AccuracyClass.classB.isOfficial, true);
      expect(AccuracyClass.classC.isOfficial, false);
      expect(AccuracyClass.classD.isOfficial, false);
    });
  });
}
