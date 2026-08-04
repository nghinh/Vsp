// Driving Zone Statistics Model Tests — VSP Mobile App
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/driving_zone_filter.dart';
import 'package:vsp_mobile/domain/models/driving_zone_statistics.dart';

void main() {
  group('ZoneCell', () {
    test('horizontalLabel returns correct label for each zone', () {
      expect(const ZoneCell(horizontalZone: -1, distanceBand: 0, shotCount: 5, percentage: 25.0).horizontalLabel, 'Left');
      expect(const ZoneCell(horizontalZone: 0, distanceBand: 0, shotCount: 5, percentage: 25.0).horizontalLabel, 'Center');
      expect(const ZoneCell(horizontalZone: 1, distanceBand: 0, shotCount: 5, percentage: 25.0).horizontalLabel, 'Right');
      expect(const ZoneCell(horizontalZone: 99, distanceBand: 0, shotCount: 5, percentage: 25.0).horizontalLabel, 'Unknown');
    });

    test('distanceLabel returns correct label for each band', () {
      expect(const ZoneCell(horizontalZone: 0, distanceBand: 0, shotCount: 5, percentage: 25.0).distanceLabel, 'Short');
      expect(const ZoneCell(horizontalZone: 0, distanceBand: 1, shotCount: 5, percentage: 25.0).distanceLabel, 'Mid');
      expect(const ZoneCell(horizontalZone: 0, distanceBand: 2, shotCount: 5, percentage: 25.0).distanceLabel, 'Long');
      expect(const ZoneCell(horizontalZone: 0, distanceBand: 99, shotCount: 5, percentage: 25.0).distanceLabel, 'Unknown');
    });

    test('description combines horizontal and distance labels', () {
      final cell = const ZoneCell(horizontalZone: 0, distanceBand: 1, shotCount: 5, percentage: 25.0);
      expect(cell.description, 'Center / Mid');
    });

    test('toJson and fromJson round-trip correctly', () {
      final original = const ZoneCell(
        horizontalZone: -1,
        distanceBand: 2,
        shotCount: 10,
        percentage: 33.3,
      );
      final json = original.toJson();
      final restored = ZoneCell.fromJson(json);
      expect(restored.horizontalZone, original.horizontalZone);
      expect(restored.distanceBand, original.distanceBand);
      expect(restored.shotCount, original.shotCount);
      expect(restored.percentage, original.percentage);
    });
  });

  group('HoleZoneStats', () {
    test('centerZonePercentage calculates correctly', () {
      final stats = HoleZoneStats(
        holeNumber: 1,
        clubId: 'driver',
        totalShots: 20,
        zoneCells: const [
          ZoneCell(horizontalZone: -1, distanceBand: 0, shotCount: 5, percentage: 25.0),
          ZoneCell(horizontalZone: 0, distanceBand: 0, shotCount: 10, percentage: 50.0),
          ZoneCell(horizontalZone: 1, distanceBand: 0, shotCount: 5, percentage: 25.0),
        ],
      );
      expect(stats.centerZonePercentage, 50.0);
    });

    test('centerZonePercentage returns 0 when no center cells', () {
      final stats = HoleZoneStats(
        holeNumber: 1,
        clubId: 'driver',
        totalShots: 10,
        zoneCells: const [
          ZoneCell(horizontalZone: -1, distanceBand: 0, shotCount: 5, percentage: 50.0),
          ZoneCell(horizontalZone: 1, distanceBand: 0, shotCount: 5, percentage: 50.0),
        ],
      );
      expect(stats.centerZonePercentage, 0.0);
    });

    test('dispersionIndex returns 0 for empty cells', () {
      final stats = HoleZoneStats(
        holeNumber: 1,
        clubId: 'driver',
        totalShots: 0,
        zoneCells: const [],
      );
      expect(stats.dispersionIndex, 0.0);
    });

    test('toJson and fromJson round-trip correctly', () {
      final original = HoleZoneStats(
        holeNumber: 5,
        clubId: 'driver',
        clubName: 'Driver',
        totalShots: 30,
        zoneCells: const [
          ZoneCell(horizontalZone: 0, distanceBand: 1, shotCount: 15, percentage: 50.0),
        ],
        averageDistanceYards: 215.5,
        averageDistanceMeters: 197.0,
        lastUpdated: DateTime(2025, 8, 1),
      );
      final json = original.toJson();
      final restored = HoleZoneStats.fromJson(json);
      expect(restored.holeNumber, original.holeNumber);
      expect(restored.clubId, original.clubId);
      expect(restored.totalShots, original.totalShots);
      expect(restored.averageDistanceYards, original.averageDistanceYards);
    });
  });

  group('DrivingZoneStatistics', () {
    test('totalShots sums all hole stats', () {
      final stats = DrivingZoneStatistics(
        filter: DrivingZoneFilter.defaultFilter(playerId: 'player-1'),
        holeStats: [
          HoleZoneStats(holeNumber: 1, clubId: 'driver', totalShots: 20, zoneCells: const []),
          HoleZoneStats(holeNumber: 2, clubId: 'driver', totalShots: 15, zoneCells: const []),
        ],
        generatedAt: DateTime.now(),
      );
      expect(stats.totalShots, 35);
    });

    test('clubIds returns unique club IDs', () {
      final stats = DrivingZoneStatistics(
        filter: DrivingZoneFilter.defaultFilter(playerId: 'player-1'),
        holeStats: [
          HoleZoneStats(holeNumber: 1, clubId: 'driver', totalShots: 20, zoneCells: const []),
          HoleZoneStats(holeNumber: 2, clubId: 'driver', totalShots: 15, zoneCells: const []),
          HoleZoneStats(holeNumber: 3, clubId: '3wood', totalShots: 10, zoneCells: const []),
        ],
        generatedAt: DateTime.now(),
      );
      expect(stats.clubIds.length, 2);
      expect(stats.clubIds, containsAll(['driver', '3wood']));
    });

    test('averageDispersion returns 0 for empty holeStats', () {
      final stats = DrivingZoneStatistics(
        filter: DrivingZoneFilter.defaultFilter(playerId: 'player-1'),
        holeStats: const [],
        generatedAt: DateTime.now(),
      );
      expect(stats.averageDispersion, 0.0);
    });
  });
}
