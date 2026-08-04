// WindStalenessGuard Unit Tests — VSP Mobile App
//
// Tests cover:
// - isWindStale: fresh vs stale wind based on timestamp
// - getWindAge: returns correct duration
// - describeWindFreshness: enum classification at various ages
// - default maxAge is 30 minutes
//
// Story 7.2 — Slice 1: Wind-Relative Calculation Engine

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/hole_map/domain/wind_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/services/wind_staleness_guard.dart';

void main() {
  WindEntity makeWind({DateTime? timestamp}) {
    return WindEntity(
      direction: 90,
      speed: 15,
      source: WindSource.official,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  group('isWindStale', () {
    test('wind less than maxAge old is not stale', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      expect(isWindStale(wind), isFalse);
    });

    test('wind exactly at maxAge boundary is not stale', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      expect(isWindStale(wind), isFalse);
    });

    test('wind older than maxAge is stale', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 31)),
      );

      expect(isWindStale(wind), isTrue);
    });

    test('wind older than 2× maxAge is stale', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(isWindStale(wind), isTrue);
    });

    test('custom maxAge is respected', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      // 5 min old — fresh with 30 min default, stale with 2 min custom
      expect(
        isWindStale(wind, maxAge: const Duration(minutes: 2)),
        isTrue,
      );
      expect(
        isWindStale(wind, maxAge: const Duration(minutes: 10)),
        isFalse,
      );
    });

    test('very fresh wind is not stale', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
      );

      expect(isWindStale(wind), isFalse);
    });

    test('default maxAge is 30 minutes', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 29)),
      );

      expect(isWindStale(wind), isFalse);
    });
  });

  group('getWindAge', () {
    test('returns zero for current timestamp', () {
      final wind = makeWind(timestamp: DateTime.now());
      final age = getWindAge(wind);

      expect(age.inSeconds, lessThan(2));
    });

    test('returns correct age for known offset', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 7)),
      );
      final age = getWindAge(wind);

      expect(age.inMinutes, greaterThanOrEqualTo(7));
      expect(age.inMinutes, lessThan(8));
    });
  });

  group('describeWindFreshness', () {
    test('fresh < 5 minutes', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      expect(describeWindFreshness(wind), WindFreshness.fresh);
    });

    test('current between 5 min and maxAge', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      );

      expect(describeWindFreshness(wind), WindFreshness.current);
    });

    test('stale between maxAge and 2× maxAge', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      );

      expect(describeWindFreshness(wind), WindFreshness.stale);
    });

    test('veryStale > 2× maxAge', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(describeWindFreshness(wind), WindFreshness.veryStale);
    });

    test('custom maxAge affects freshness classification', () {
      final wind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      );

      // 8 min — fresh with 30 min default, stale with 5 min custom
      expect(
        describeWindFreshness(wind, maxAge: const Duration(minutes: 5)),
        WindFreshness.stale,
      );
      expect(
        describeWindFreshness(wind, maxAge: const Duration(minutes: 30)),
        WindFreshness.current,
      );
    });
  });

  group('defaultWindMaxAge constant', () {
    test('defaultWindMaxAge is 30 minutes', () {
      expect(defaultWindMaxAge.inMinutes, 30);
    });
  });
}
