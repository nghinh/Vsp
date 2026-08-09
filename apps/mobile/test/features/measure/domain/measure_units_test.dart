// MeasureUnits Unit Tests — VSP Mobile App
//
// Tests cover:
// - Metres ↔ yards conversion, matching the factor the rest of the app uses
// - Display formatting in both units
// - Tolerance formatting, which must round UP so we never advertise more
//   precision than the measurement has

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/distance_measurement.dart';
import 'package:vsp_mobile/domain/value_objects/distance_type.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

void main() {
  group('convert', () {
    test('leaves metres untouched', () {
      expect(MeasureUnits.convert(152.4, DistanceUnit.meters), 152.4);
    });

    test('converts metres to yards', () {
      expect(
        MeasureUnits.convert(100, DistanceUnit.yards),
        closeTo(109.361, 0.001),
      );
    });

    test('uses the same factor as DistanceMeasurement', () {
      const measurement = DistanceMeasurement(
        valueMeters: 137.0,
        type: DistanceType.target,
        source: DistanceSource.estimated,
        timestamp: null,
        gpsAccuracyMeters: 5,
        confidence: 0.8,
      );
      expect(
        MeasureUnits.convert(137.0, DistanceUnit.yards),
        closeTo(measurement.valueYards, 1e-9),
      );
    });

    test('round-trips through zero', () {
      expect(MeasureUnits.convert(0, DistanceUnit.yards), 0);
    });
  });

  group('format', () {
    test('renders metres with the m suffix', () {
      expect(MeasureUnits.format(152.4, DistanceUnit.meters), '152 m');
    });

    test('renders yards with the yd suffix', () {
      expect(MeasureUnits.format(100, DistanceUnit.yards), '109 yd');
    });

    test('rounds to the nearest whole unit', () {
      expect(MeasureUnits.format(151.6, DistanceUnit.meters), '152 m');
      expect(MeasureUnits.format(151.4, DistanceUnit.meters), '151 m');
    });

    test('suffix reflects the unit', () {
      expect(MeasureUnits.suffix(DistanceUnit.meters), 'm');
      expect(MeasureUnits.suffix(DistanceUnit.yards), 'yd');
    });
  });

  group('formatTolerance', () {
    test('rounds up rather than down', () {
      // 5.1 m must never read as ±5 m.
      expect(MeasureUnits.formatTolerance(5.1, DistanceUnit.meters), '±6 m');
    });

    test('keeps whole values whole', () {
      expect(MeasureUnits.formatTolerance(7.0, DistanceUnit.meters), '±7 m');
    });

    test('converts before rounding up', () {
      // 6.4 m ≈ 7.0 yd
      expect(MeasureUnits.formatTolerance(6.4, DistanceUnit.yards), '±7 yd');
    });

    test('a zero tolerance stays zero', () {
      expect(MeasureUnits.formatTolerance(0, DistanceUnit.meters), '±0 m');
    });
  });

  test('useYards mirrors the preference', () {
    expect(MeasureUnits.useYards(DistanceUnit.yards), isTrue);
    expect(MeasureUnits.useYards(DistanceUnit.meters), isFalse);
  });

  group('when the golfer is nowhere near the course', () {
    // Opening a round set at Long Thành while sitting in Hà Nội printed the
    // distance to the green as "1135481 m". The number was exactly right, which
    // is what makes it dangerous: seven unreadable digits look like a broken
    // calculation, and a golfer who learns to distrust one distance distrusts
    // the 152 m one too.
    test('a distance no hole could be reads in kilometres', () {
      expect(MeasureUnits.format(1135481, DistanceUnit.meters), '1135 km');
    });

    test('a yards golfer gets miles, not kilometres', () {
      // Making someone who thinks in yards convert twice is its own small
      // failure.
      expect(MeasureUnits.format(1135481, DistanceUnit.yards), '706 mi');
    });

    test('single-digit distances keep one decimal', () {
      expect(MeasureUnits.format(4200, DistanceUnit.meters), '4.2 km');
    });

    test('a distance a hole could actually be is untouched', () {
      // The threshold must not reach anything playable. The longest hole ever
      // built is under a kilometre.
      expect(MeasureUnits.format(2999, DistanceUnit.meters), '2999 m');
      expect(MeasureUnits.format(152, DistanceUnit.meters), '152 m');
      expect(MeasureUnits.isOffCourse(950), isFalse);
    });
  });
}
