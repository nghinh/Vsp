// ConditionEntry unit tests — VSP Mobile App
//
// Tests cover:
// - ConditionType, ConditionSeverity, ConditionSource enum parsing
// - isOfficial: true when source == ConditionSource.official
// - isExpired: true when expiryDate is set and has passed
// - fromJson/toJson round-trip with all fields
// - copyWith creates new instance with updated fields
//
// Story 7.3 — Slice 5: Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/condition_entry.dart';

void main() {
  group('ConditionType', () {
    test('fromString handles known values case-insensitively', () {
      expect(ConditionType.fromString('PIN_POSITION'), ConditionType.pinPosition);
      expect(ConditionType.fromString('pin_position'), ConditionType.pinPosition);
      expect(ConditionType.fromString('GREEN_SPEED'), ConditionType.greenSpeed);
      expect(ConditionType.fromString('COURSE_CONDITION'), ConditionType.courseCondition);
      expect(ConditionType.fromString('BUNKER_CONDITION'), ConditionType.bunkerCondition);
      expect(ConditionType.fromString('CART_PATH'), ConditionType.cartPath);
      expect(ConditionType.fromString('LOCAL_RULE'), ConditionType.localRule);
      expect(ConditionType.fromString('ALERT'), ConditionType.alert);
    });

    test('fromString defaults to courseCondition for unknown values', () {
      expect(ConditionType.fromString('UNKNOWN'), ConditionType.courseCondition);
      expect(ConditionType.fromString(''), ConditionType.courseCondition);
    });

    test('displayLabel returns human-readable labels', () {
      expect(ConditionType.pinPosition.displayLabel, 'Pin Position');
      expect(ConditionType.greenSpeed.displayLabel, 'Green Speed');
      expect(ConditionType.courseCondition.displayLabel, 'Course Condition');
      expect(ConditionType.bunkerCondition.displayLabel, 'Bunker Condition');
      expect(ConditionType.cartPath.displayLabel, 'Cart Path');
      expect(ConditionType.localRule.displayLabel, 'Local Rule');
      expect(ConditionType.alert.displayLabel, 'Alert');
    });
  });

  group('ConditionSeverity', () {
    test('fromString handles known values case-insensitively', () {
      expect(ConditionSeverity.fromString('INFO'), ConditionSeverity.info);
      expect(ConditionSeverity.fromString('info'), ConditionSeverity.info);
      expect(ConditionSeverity.fromString('MINOR'), ConditionSeverity.minor);
      expect(ConditionSeverity.fromString('MODERATE'), ConditionSeverity.moderate);
      expect(ConditionSeverity.fromString('MAJOR'), ConditionSeverity.major);
    });

    test('fromString defaults to info for unknown values', () {
      expect(ConditionSeverity.fromString('UNKNOWN'), ConditionSeverity.info);
      expect(ConditionSeverity.fromString(''), ConditionSeverity.info);
    });

    test('displayLabel returns human-readable labels', () {
      expect(ConditionSeverity.info.displayLabel, 'Info');
      expect(ConditionSeverity.minor.displayLabel, 'Minor');
      expect(ConditionSeverity.moderate.displayLabel, 'Moderate');
      expect(ConditionSeverity.major.displayLabel, 'Major');
    });
  });

  group('ConditionSource', () {
    test('fromString handles known values case-insensitively', () {
      expect(ConditionSource.fromString('OFFICIAL'), ConditionSource.official);
      expect(ConditionSource.fromString('official'), ConditionSource.official);
      expect(ConditionSource.fromString('ESTIMATED'), ConditionSource.estimated);
      expect(ConditionSource.fromString('MANUAL'), ConditionSource.manual);
      expect(ConditionSource.fromString('CROWD_SOURCED'), ConditionSource.crowdSourced);
    });

    test('fromString defaults to manual for unknown values', () {
      expect(ConditionSource.fromString('UNKNOWN'), ConditionSource.manual);
      expect(ConditionSource.fromString(''), ConditionSource.manual);
    });

    test('displayLabel returns human-readable labels', () {
      expect(ConditionSource.official.displayLabel, 'Official');
      expect(ConditionSource.estimated.displayLabel, 'Estimated');
      expect(ConditionSource.manual.displayLabel, 'Manual');
      expect(ConditionSource.crowdSourced.displayLabel, 'Crowd-Sourced');
    });
  });

  group('ConditionEntry', () {
    group('isOfficial', () {
      test('isOfficial is true when source is official', () {
        final condition = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          source: ConditionSource.official,
          confidence: 0.9,
        );

        expect(condition.isOfficial, isTrue);
      });

      test('isOfficial is false for estimated source', () {
        final condition = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          source: ConditionSource.estimated,
          confidence: 0.7,
        );

        expect(condition.isOfficial, isFalse);
      });

      test('isOfficial is false when source is null', () {
        final condition = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          source: null,
        );

        expect(condition.isOfficial, isFalse);
      });
    });

    group('isExpired — AC1 verification', () {
      test('isExpired is false when expiryDate is null', () {
        final condition = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          expiryDate: null,
        );

        expect(condition.isExpired, isFalse);
      });

      test('isExpired is false when expiryDate is in the future', () {
        final condition = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          expiryDate: DateTime.now().add(const Duration(days: 7)),
        );

        expect(condition.isExpired, isFalse);
      });

      test('isExpired is true when expiryDate is in the past', () {
        final condition = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(condition.isExpired, isTrue);
      });
    });

    group('fromJson — all fields parsed', () {
      test('parses full ConditionEntry response', () {
        final json = {
          'conditionType': 'PIN_POSITION',
          'severity': 'MODERATE',
          'description': 'Front-left pin',
          'effectiveDate': '2026-07-20T00:00:00Z',
          'accuracyClass': 'B',
          'source': 'OFFICIAL',
          'confidence': 0.92,
          'expiryDate': '2026-08-20T00:00:00Z',
        };

        final entry = ConditionEntry.fromJson(json);

        expect(entry.conditionType, ConditionType.pinPosition);
        expect(entry.severity, ConditionSeverity.moderate);
        expect(entry.description, 'Front-left pin');
        expect(entry.effectiveDate, DateTime.parse('2026-07-20T00:00:00Z'));
        expect(entry.accuracyClass, 'B');
        expect(entry.source, ConditionSource.official);
        expect(entry.confidence, 0.92);
        expect(entry.expiryDate, DateTime.parse('2026-08-20T00:00:00Z'));
      });

      test('handles null optional fields', () {
        final json = {
          'conditionType': 'COURSE_CONDITION',
          'severity': 'INFO',
          'accuracyClass': 'D',
        };

        final entry = ConditionEntry.fromJson(json);

        expect(entry.description, isNull);
        expect(entry.effectiveDate, isNull);
        expect(entry.source, isNull);
        expect(entry.confidence, isNull);
        expect(entry.expiryDate, isNull);
      });

      test('defaults to courseCondition for unknown conditionType', () {
        final json = {
          'conditionType': 'UNKNOWN_TYPE',
          'severity': 'INFO',
          'accuracyClass': 'D',
        };

        final entry = ConditionEntry.fromJson(json);

        expect(entry.conditionType, ConditionType.courseCondition);
      });

      test('defaults to info for unknown severity', () {
        final json = {
          'conditionType': 'COURSE_CONDITION',
          'severity': 'UNKNOWN',
          'accuracyClass': 'D',
        };

        final entry = ConditionEntry.fromJson(json);

        expect(entry.severity, ConditionSeverity.info);
      });

      test('defaults to class D for null accuracyClass', () {
        final json = {
          'conditionType': 'COURSE_CONDITION',
          'severity': 'INFO',
        };

        final entry = ConditionEntry.fromJson(json);

        expect(entry.accuracyClass, 'D');
      });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all fields correctly', () {
        final entry = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          description: 'Front-left pin',
          effectiveDate: DateTime.parse('2026-07-20T00:00:00Z'),
          accuracyClass: 'B',
          source: ConditionSource.official,
          confidence: 0.92,
          expiryDate: DateTime.parse('2026-08-20T00:00:00Z'),
        );

        final json = entry.toJson();
        final roundTrip = ConditionEntry.fromJson(json);

        expect(roundTrip.conditionType, entry.conditionType);
        expect(roundTrip.severity, entry.severity);
        expect(roundTrip.description, entry.description);
        expect(roundTrip.effectiveDate, entry.effectiveDate);
        expect(roundTrip.accuracyClass, entry.accuracyClass);
        expect(roundTrip.source, entry.source);
        expect(roundTrip.confidence, entry.confidence);
        expect(roundTrip.expiryDate, entry.expiryDate);
      });

      test('omits null optional fields', () {
        final entry = ConditionEntry(
          conditionType: ConditionType.courseCondition,
          severity: ConditionSeverity.info,
          accuracyClass: 'D',
        );

        final json = entry.toJson();

        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('effectiveDate'), isFalse);
        expect(json.containsKey('source'), isFalse);
        expect(json.containsKey('confidence'), isFalse);
        expect(json.containsKey('expiryDate'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates new instance with updated source', () {
        final original = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          source: ConditionSource.estimated,
          confidence: 0.7,
        );

        final updated = original.copyWith(
          source: ConditionSource.official,
          confidence: 0.95,
        );

        expect(updated.conditionType, original.conditionType);
        expect(updated.severity, original.severity);
        expect(updated.accuracyClass, original.accuracyClass);
        expect(updated.source, ConditionSource.official);
        expect(updated.confidence, 0.95);
      });

      test('preserves original when no parameters provided', () {
        final original = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          source: ConditionSource.official,
          confidence: 0.9,
          expiryDate: DateTime(2026, 8, 1),
        );

        final copy = original.copyWith();

        expect(copy.conditionType, original.conditionType);
        expect(copy.expiryDate, original.expiryDate);
        expect(copy.confidence, original.confidence);
      });
    });

    group('props — Equatable', () {
      test('two entries with same props are equal', () {
        final entry1 = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          description: 'Front-left pin',
          effectiveDate: DateTime(2026, 7, 20),
          accuracyClass: 'B',
          source: ConditionSource.official,
          confidence: 0.92,
          expiryDate: DateTime(2026, 8, 20),
        );

        final entry2 = ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          description: 'Front-left pin',
          effectiveDate: DateTime(2026, 7, 20),
          accuracyClass: 'B',
          source: ConditionSource.official,
          confidence: 0.92,
          expiryDate: DateTime(2026, 8, 20),
        );

        expect(entry1, equals(entry2));
      });
    });
  });
}
