// ClubPerformanceRepository Unit Tests — VSP Mobile App
//
// Tests for InMemoryClubPerformanceRepository stub.
//
// Story 11.4 — Slice 1: Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/repositories/club_performance_repository.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/repositories/in_memory_club_performance_repository.dart';

void main() {
  late InMemoryClubPerformanceRepository repo;

  final seedStats = [
    const ClubPerformanceStats(
      clubId: 'club-7',
      clubName: '7 Iron',
      loftDegrees: 34.0,
      avgCarryMeters: 150.0,
      medianCarryMeters: 149.0,
      dispersionMeters: 8.0,
      leftBiasMeters: 2.0,
      rightBiasMeters: 3.0,
      sampleCount: 50,
      confidence: 0.9,
    ),
    const ClubPerformanceStats(
      clubId: 'club-5',
      clubName: '5 Iron',
      loftDegrees: 27.0,
      avgCarryMeters: 170.0,
      medianCarryMeters: 168.0,
      dispersionMeters: 10.0,
      leftBiasMeters: 3.0,
      rightBiasMeters: 4.0,
      sampleCount: 10,
      confidence: 0.5,
    ),
    const ClubPerformanceStats(
      clubId: 'club-driver',
      clubName: 'Driver',
      loftDegrees: 10.5,
      avgCarryMeters: 220.0,
      medianCarryMeters: 218.0,
      dispersionMeters: 20.0,
      leftBiasMeters: 5.0,
      rightBiasMeters: 6.0,
      sampleCount: 3,
      confidence: 0.3,
    ),
  ];

  setUp(() {
    repo = InMemoryClubPerformanceRepository(seeds: seedStats);
  });

  group('ClubPerformanceStats', () {
    test('fromJson / toJson round-trip is lossless', () {
      const stats = ClubPerformanceStats(
        clubId: 'club-7',
        clubName: '7 Iron',
        loftDegrees: 34.0,
        avgCarryMeters: 150.0,
        medianCarryMeters: 149.0,
        dispersionMeters: 8.0,
        leftBiasMeters: 2.0,
        rightBiasMeters: 3.0,
        sampleCount: 50,
        confidence: 0.9,
      );
      final restored = ClubPerformanceStats.fromJson(stats.toJson());
      expect(restored, stats);
    });
  });

  group('InMemoryClubPerformanceRepository', () {
    test('getByClubId returns correct stats', () async {
      final stats = await repo.getByClubId('club-7');
      expect(stats, isNotNull);
      expect(stats!.clubId, 'club-7');
      expect(stats.avgCarryMeters, 150.0);
    });

    test('getByClubId returns null for unknown club', () async {
      final stats = await repo.getByClubId('club-unknown');
      expect(stats, isNull);
    });

    test('getAllForPlayer returns all clubs', () async {
      final all = await repo.getAllForPlayer('any-player');
      expect(all.length, 3);
    });

    test('getReliableClubs filters by minSampleCount', () async {
      final reliable = await repo.getReliableClubs(
        'any-player',
        minSampleCount: 20,
      );
      expect(reliable.length, 1);
      expect(reliable.first.clubId, 'club-7');
    });

    test('hasSufficientData returns true when enough clubs', () async {
      final sufficient = await repo.hasSufficientData(
        'any-player',
        minClubs: 2,
      );
      expect(sufficient, true);
    });

    test('hasSufficientData returns false when not enough clubs', () async {
      final sufficient = await repo.hasSufficientData(
        'any-player',
        minClubs: 5,
      );
      expect(sufficient, false);
    });

    test('addStats adds new club stats', () async {
      repo.addStats(const ClubPerformanceStats(
        clubId: 'club-new',
        clubName: 'New Club',
        avgCarryMeters: 130.0,
        medianCarryMeters: 129.0,
        dispersionMeters: 7.0,
        leftBiasMeters: 1.0,
        rightBiasMeters: 2.0,
        sampleCount: 100,
        confidence: 0.95,
      ));

      final stats = await repo.getByClubId('club-new');
      expect(stats, isNotNull);
      expect(stats!.clubName, 'New Club');
    });

    test('clear removes all stats', () async {
      repo.clear();
      final all = await repo.getAllForPlayer('any-player');
      expect(all, isEmpty);
    });
  });
}
