// Driving Zone Filter Model Tests — VSP Mobile App
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/driving_zone_filter.dart';

void main() {
  group('WindCondition', () {
    test('fromString returns correct enum for known values', () {
      expect(WindCondition.fromString('headwind'), WindCondition.headwind);
      expect(WindCondition.fromString('tailwind'), WindCondition.tailwind);
      expect(WindCondition.fromString('crosswind_left'), WindCondition.crosswindLeft);
      expect(WindCondition.fromString('calm'), WindCondition.calm);
    });

    test('fromString returns any for null input', () {
      expect(WindCondition.fromString(null), WindCondition.any);
    });

    test('fromString normalizes hyphenated and underscored values', () {
      expect(WindCondition.fromString('cross-wind-left'), WindCondition.crosswindLeft);
    });

    test('toApiValue returns correct string representation', () {
      expect(WindCondition.any.toApiValue(), 'any');
      expect(WindCondition.headwind.toApiValue(), 'headwind');
      expect(WindCondition.crosswindLeft.toApiValue(), 'crosswind_left');
    });
  });

  group('TimeRange', () {
    test('isEmpty returns true when both start and end are null', () {
      expect(const TimeRange().isEmpty, true);
    });

    test('isEmpty returns false when start is set', () {
      expect(
        TimeRange(start: DateTime.now(), end: null).isEmpty,
        false,
      );
    });

    test('last30Days has start approximately 30 days ago', () {
      final range = TimeRange.last30Days();
      final diff = DateTime.now().difference(range.start!);
      expect(diff.inDays, 30);
    });

    test('last90Days has start approximately 90 days ago', () {
      final range = TimeRange.last90Days();
      final diff = DateTime.now().difference(range.start!);
      expect(diff.inDays, 90);
    });

    test('yearToDate starts on Jan 1 of current year', () {
      final range = TimeRange.yearToDate();
      final now = DateTime.now();
      expect(range.start!.month, 1);
      expect(range.start!.day, 1);
      expect(range.start!.year, now.year);
    });

    test('allTime has null start and end', () {
      expect(TimeRange.allTime().isEmpty, true);
    });

    test('toJson and fromJson round-trip correctly', () {
      final original = TimeRange(
        start: DateTime(2025, 1, 1),
        end: DateTime(2025, 12, 31),
      );
      final json = original.toJson();
      final restored = TimeRange.fromJson(json);
      expect(restored.start, original.start);
      expect(restored.end, original.end);
    });
  });

  group('DrivingZoneFilter', () {
    test('defaultFilter creates all-time filter with minimumShotCount 5', () {
      final filter = DrivingZoneFilter.defaultFilter(playerId: 'player-1');
      expect(filter.playerId, 'player-1');
      expect(filter.timeRange.isEmpty, true);
      expect(filter.minimumShotCount, 5);
      expect(filter.clubIds, isEmpty);
      expect(filter.teeSetId, isNull);
      expect(filter.windCondition, isNull);
    });

    test('copyWith updates specified fields', () {
      final original = DrivingZoneFilter.defaultFilter(playerId: 'player-1');
      final updated = original.copyWith(
        clubIds: ['driver'],
        windCondition: WindCondition.headwind,
      );
      expect(updated.clubIds, ['driver']);
      expect(updated.windCondition, WindCondition.headwind);
      expect(updated.playerId, original.playerId);
    });

    test('copyWith clearTeeSetId removes teeSetId', () {
      final original = DrivingZoneFilter(
        playerId: 'player-1',
        teeSetId: 'tee-1',
      );
      final updated = original.copyWith(clearTeeSetId: true);
      expect(updated.teeSetId, isNull);
    });

    test('copyWith clearWindCondition removes windCondition', () {
      final original = DrivingZoneFilter(
        playerId: 'player-1',
        windCondition: WindCondition.calm,
      );
      final updated = original.copyWith(clearWindCondition: true);
      expect(updated.windCondition, isNull);
    });

    test('toJson and fromJson round-trip correctly', () {
      final original = DrivingZoneFilter(
        playerId: 'player-1',
        timeRange: TimeRange.last30Days(),
        clubIds: ['driver', '3wood'],
        teeSetId: 'member',
        windCondition: WindCondition.headwind,
        minimumShotCount: 10,
      );
      final json = original.toJson();
      final restored = DrivingZoneFilter.fromJson(json);
      expect(restored.playerId, original.playerId);
      expect(restored.clubIds, original.clubIds);
      expect(restored.teeSetId, original.teeSetId);
      expect(restored.windCondition, original.windCondition);
      expect(restored.minimumShotCount, original.minimumShotCount);
    });

    test('props includes all fields for Equatable equality', () {
      final a = DrivingZoneFilter.defaultFilter(playerId: 'player-1');
      final b = DrivingZoneFilter.defaultFilter(playerId: 'player-1');
      expect(a, b);
    });
  });
}
