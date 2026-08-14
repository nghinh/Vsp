// Every distance a golfer reads is in the unit they chose.
//
// The app accumulated roughly forty places printing a hardcoded `m` or `yd`
// before MeasureUnits existed, including two that disagreed about the same
// club's carry. This asserts the rule rather than the forty fixes: a tolerance
// is a distance, so it follows the preference like every other one.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

void main() {
  group('a tolerance follows the golfer\'s unit', () {
    test('renders metres for a metres golfer', () {
      expect(
        MeasureUnits.formatTolerance(8.2, DistanceUnit.meters),
        '±9 m',
      );
    });

    test('renders yards for a yards golfer', () {
      expect(
        MeasureUnits.formatTolerance(8.2, DistanceUnit.yards),
        '±9 yd',
      );
    });

    // Rounds up, always. A tolerance that rounds down reads as more precision
    // than the fix actually has.
    test('never understates the tolerance', () {
      expect(MeasureUnits.formatTolerance(5.1, DistanceUnit.meters), '±6 m');
      expect(MeasureUnits.formatTolerance(5.0, DistanceUnit.meters), '±5 m');
    });

    // The pairing that made this worth fixing: "152 yd" beside "±5 m" is the
    // app disagreeing with itself on one line.
    test('agrees with the distance printed next to it', () {
      const unit = DistanceUnit.yards;
      final distance = MeasureUnits.format(139.0, unit);
      final tolerance = MeasureUnits.formatTolerance(5.0, unit);

      expect(distance, endsWith('yd'));
      expect(tolerance, endsWith('yd'));
    });
  });
}
