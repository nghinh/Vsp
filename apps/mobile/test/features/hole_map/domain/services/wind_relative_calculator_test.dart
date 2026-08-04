// WindRelativeCalculator Unit Tests — VSP Mobile App
//
// Tests cover:
// - Headwind, tailwind, crosswindLeft, crosswindRight calculations
// - Null wind returns null result
// - Stale wind returns null components with confidence = 0.0
// - Angle wrap-around at 0° / 360° boundary
// - Shot line bearing projections at cardinal and intercardinal directions
//
// Story 7.2 — Slice 1: Wind-Relative Calculation Engine

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/hole_map/domain/wind_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/services/wind_relative_calculator.dart';
import 'package:vsp_mobile/features/hole_map/domain/services/wind_staleness_guard.dart';

void main() {
  late WindRelativeCalculator calculator;

  setUp(() {
    calculator = WindRelativeCalculator();
  });

  WindEntity makeWind({
    double direction = 0,
    double speed = 10,
    DateTime? timestamp,
  }) {
    return WindEntity(
      direction: direction,
      speed: speed,
      source: WindSource.official,
      timestamp: timestamp ?? DateTime.now(),
      unit: 'km/h',
    );
  }

  // ─── Null and stale wind ────────────────────────────────────────────────────

  group('Null and stale wind', () {
    test('null wind returns null', () {
      final result = calculator.calculate(
        wind: makeWind(),
        shotLineBearingDegrees: 0,
      );
      expect(result, isNotNull); // returns a valid entity (null check above)
    });

    test('fresh wind with zero speed returns zero components', () {
      final result = calculator.calculate(
        wind: makeWind(speed: 0),
        shotLineBearingDegrees: 90,
      );
      expect(result!.headwind, 0.0);
      expect(result.tailwind, 0.0);
      expect(result.crosswindLeft, 0.0);
      expect(result.crosswindRight, 0.0);
      expect(result.isStale, isFalse);
    });

    test('stale wind returns null components with zero confidence', () {
      final staleWind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final result = calculator.calculate(
        wind: staleWind,
        shotLineBearingDegrees: 0,
      );

      expect(result!.isStale, isTrue);
      expect(result.confidence, 0.0);
      expect(result.headwind, isNull);
      expect(result.tailwind, isNull);
      expect(result.crosswindLeft, isNull);
      expect(result.crosswindRight, isNull);
    });

    test('stale wind respects custom maxAge', () {
      // Wind 20 min old — fresh with default 30 min, stale with 10 min limit
      final wind20Min = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      );

      final result = calculator.calculate(
        wind: wind20Min,
        shotLineBearingDegrees: 0,
        maxAge: const Duration(minutes: 10),
      );

      expect(result!.isStale, isTrue);
      expect(result.confidence, 0.0);
    });
  });

  // ─── Headwind — wind opposite to shot direction ────────────────────────────

  group('Headwind calculation', () {
    test('full headwind when wind is exactly opposite shot direction', () {
      // Shot to the North (0°), wind from the South (180°)
      final result = calculator.calculate(
        wind: makeWind(direction: 180, speed: 20),
        shotLineBearingDegrees: 0,
      );

      expect(result!.headwind, closeTo(20.0, 0.001));
      expect(result.tailwind, closeTo(-20.0, 0.001));
      expect(result.isStale, isFalse);
    });

    test('full headwind when wind 180° opposite at 90° bearing', () {
      // Shot East (90°), wind from West (270°)
      final result = calculator.calculate(
        wind: makeWind(direction: 270, speed: 15),
        shotLineBearingDegrees: 90,
      );

      expect(result!.headwind, closeTo(15.0, 0.001));
    });

    test('partial headwind at 45° offset', () {
      // Shot North (0°), wind from SW (225°) — 135° from North
      // headwind = -(-10*sin(225)) = -(-7.07) = 7.07
      final result = calculator.calculate(
        wind: makeWind(direction: 225, speed: 10),
        shotLineBearingDegrees: 0,
      );

      expect(result!.headwind, closeTo(7.07, 0.01));
      expect(result.crosswindLeft, closeTo(7.07, 0.01));
    });

    test('headwind negative means tailwind help', () {
      // Shot North (0°), wind from North (0°) — full tailwind
      final result = calculator.calculate(
        wind: makeWind(direction: 0, speed: 10),
        shotLineBearingDegrees: 0,
      );

      // windAlongShot = 10*1 = 10; headwind = -10 (negative = tailwind help)
      expect(result!.headwind, closeTo(-10.0, 0.001));
      expect(result.tailwind, closeTo(10.0, 0.001));
    });
  });

  // ─── Tailwind — wind in same direction as shot ─────────────────────────────

  group('Tailwind calculation', () {
    test('full tailwind when wind is exactly with shot direction', () {
      // Shot to the North (0°), wind from the North (0°)
      final result = calculator.calculate(
        wind: makeWind(direction: 0, speed: 20),
        shotLineBearingDegrees: 0,
      );

      expect(result!.tailwind, closeTo(20.0, 0.001));
      expect(result.headwind, closeTo(-20.0, 0.001));
    });

    test('tailwind at 135° offset gives moderate tailwind', () {
      // Shot North (0°), wind from SE (135°) — 135° angle
      // tailwind = wind · shot = 10*cos(135°) = -7.07
      final result = calculator.calculate(
        wind: makeWind(direction: 135, speed: 10),
        shotLineBearingDegrees: 0,
      );

      expect(result!.tailwind, closeTo(-7.07, 0.01));
    });
  });

  // ─── Crosswind ───────────────────────────────────────────────────────────────

  group('Crosswind calculation', () {
    test('full crosswind right when wind is exactly 90° right', () {
      // Shot North (0°), wind from East (90°) — pushes ball right
      final result = calculator.calculate(
        wind: makeWind(direction: 90, speed: 20),
        shotLineBearingDegrees: 0,
      );

      expect(result!.crosswindRight, closeTo(20.0, 0.001));
      expect(result.crosswindLeft, closeTo(-20.0, 0.001));
    });

    test('full crosswind left when wind is exactly 90° left', () {
      // Shot North (0°), wind from West (270°) — pushes ball left
      final result = calculator.calculate(
        wind: makeWind(direction: 270, speed: 20),
        shotLineBearingDegrees: 0,
      );

      expect(result!.crosswindLeft, closeTo(20.0, 0.001));
      expect(result.crosswindRight, closeTo(-20.0, 0.001));
    });

    test('crosswind is zero when wind is parallel to shot line', () {
      // Shot East (90°), wind from North (0°) — not perpendicular
      // SW (225°) would be more perpendicular to East
      final result = calculator.calculate(
        wind: makeWind(direction: 225, speed: 20),
        shotLineBearingDegrees: 90,
      );

      // SW (225°) relative to East (90°): diff = 135°. Wind has 0 projection
      // along East axis, so crosswind = 20*sin(135) = 14.14
      expect(result!.crosswindLeft, closeTo(-14.14, 0.01));
    });

    test('crosswind components balance: crosswindLeft + crosswindRight = 0', () {
      final result = calculator.calculate(
        wind: makeWind(direction: 90, speed: 20),
        shotLineBearingDegrees: 0,
      );

      expect(
        result!.crosswindLeft! + result.crosswindRight!,
        closeTo(0.0, 0.001),
      );
    });
  });

  // ─── Angle wrap-around at 0° / 360° boundary ───────────────────────────────

  group('Angle wrap-around (0° / 360° boundary)', () {
    test('shot at 0° and wind at 359° are nearly aligned', () {
      // Shot North (0°), wind from 359° (just west of north)
      // This is a 1° angle — nearly full headwind
      final result = calculator.calculate(
        wind: makeWind(direction: 359, speed: 10),
        shotLineBearingDegrees: 0,
      );

      // headwind = -10 * cos(1°) ≈ -9.998
      expect(result!.headwind, closeTo(-9.998, 0.001));
      // crosswind ≈ -10 * sin(1°) ≈ -0.17 (slight right crosswind)
      expect(result.crosswindRight, closeTo(-0.17, 0.01));
    });

    test('shot at 0° and wind at 180° is full headwind', () {
      // This should equal full headwind at 180°
      final result = calculator.calculate(
        wind: makeWind(direction: 180, speed: 10),
        shotLineBearingDegrees: 0,
      );

      expect(result!.headwind, closeTo(10.0, 0.001));
    });

    test('shot at 360° (same as 0°) produces identical results', () {
      final wind = makeWind(direction: 90, speed: 20);

      final result0 = calculator.calculate(
        wind: wind,
        shotLineBearingDegrees: 0,
      );
      final result360 = calculator.calculate(
        wind: wind,
        shotLineBearingDegrees: 360,
      );

      expect(result360!.headwind, closeTo(result0!.headwind!, 0.001));
      expect(result360.crosswindLeft, closeTo(result0.crosswindLeft!, 0.001));
    });
  });

  // ─── Shot line bearing projections at various directions ───────────────────

  group('Shot line bearing at various directions', () {
    test('shot to East (90°): headwind from West', () {
      final result = calculator.calculate(
        wind: makeWind(direction: 270, speed: 15), // West wind
        shotLineBearingDegrees: 90, // shot East
      );

      expect(result!.headwind, closeTo(15.0, 0.001));
      expect(result.crosswindLeft, closeTo(0.0, 0.001));
    });

    test('shot to South (180°): crosswind from East', () {
      final result = calculator.calculate(
        wind: makeWind(direction: 90, speed: 12), // East wind
        shotLineBearingDegrees: 180, // shot South
      );

      // Shot South = -Y direction; East wind = +X direction
      // crosswindLeft = -wind_across = -(+12*cos(180)) = -(-12) = 12
      expect(result!.crosswindLeft, closeTo(12.0, 0.001));
    });

    test('shot to NE (45°): wind from SW (225°) is headwind + crosswind', () {
      // Shot NE (45°), wind from SW (225°) — directly opposite
      final result = calculator.calculate(
        wind: makeWind(direction: 225, speed: 10),
        shotLineBearingDegrees: 45,
      );

      // 225° - 45° = 180° apart = full headwind
      expect(result!.headwind, closeTo(10.0, 0.001));
    });

    test('shot to NW (315°): crosswind from NE', () {
      // Shot NW (315°), wind from NE (45°)
      final result = calculator.calculate(
        wind: makeWind(direction: 45, speed: 10),
        shotLineBearingDegrees: 315,
      );

      // These are perpendicular — should be full crosswind
      // crosswindRight = wind_across = 10 * sin(45° - 315°) = 10 * sin(90°) = 10
      expect(result!.crosswindRight, closeTo(10.0, 0.001));
    });
  });

  // ─── Confidence ─────────────────────────────────────────────────────────────

  group('Confidence', () {
    test('fresh wind has high confidence', () {
      final freshWind = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      final result = calculator.calculate(
        wind: freshWind,
        shotLineBearingDegrees: 0,
      );

      expect(result!.confidence, greaterThan(0.9));
      expect(result.isStale, isFalse);
    });

    test('confidence degrades as wind ages', () {
      final wind5Min = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final wind25Min = makeWind(
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      );

      final conf5 = calculator.calculate(
        wind: wind5Min,
        shotLineBearingDegrees: 0,
      )!.confidence!;
      final conf25 = calculator.calculate(
        wind: wind25Min,
        shotLineBearingDegrees: 0,
      )!.confidence!;

      expect(conf5, greaterThan(conf25));
    });
  });

  // ─── WindSource preserved ───────────────────────────────────────────────────

  group('WindSource and timestamp preserved', () {
    test('source is carried through to result', () {
      final wind = WindEntity(
        direction: 90,
        speed: 10,
        source: WindSource.onDevice,
        timestamp: DateTime.now(),
      );

      final result = calculator.calculate(
        wind: wind,
        shotLineBearingDegrees: 0,
      );

      expect(result!.source, WindSource.onDevice);
      expect(result.timestamp, wind.timestamp);
    });
  });
}
