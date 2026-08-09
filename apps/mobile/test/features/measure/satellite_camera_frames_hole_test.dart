// Tests for what the satellite view points at when it opens.
//
// It opened on the golfer whenever there was a fix. That is right on the
// course and wrong everywhere else: opening Long Thành from an office in Hà
// Nội framed a street 1135 km from the hole, which reads as a broken map
// rather than an accurate one. Observed on a device with real imagery — the
// picture was sharp, correct, and of the wrong place.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';

void main() {
  // Long Thành hole 1, and an office in Hà Nội.
  const holeLat = 10.8595, holeLng = 106.9006;
  const officeLat = 21.0184736, officeLng = 105.8091544;
  // Standing on the tee.
  const teeLat = 10.8580, teeLng = 106.9000;

  group('is the golfer on this hole', () {
    test('a golfer on the tee is', () {
      expect(
        SatelliteMeasureView.debugIsOnHole(
          teeLat, teeLng, holeLat, holeLng,
        ),
        isTrue,
      );
    });

    test('a golfer in another province is not', () {
      expect(
        SatelliteMeasureView.debugIsOnHole(
          officeLat, officeLng, holeLat, holeLng,
        ),
        isFalse,
      );
    });

    test('the threshold is past the longest hole ever built', () {
      // ~950 m north of the hole: absurd for a golf hole, but still the same
      // course, and a golfer walking off the 18th should not have the camera
      // jump away from them.
      expect(
        SatelliteMeasureView.debugIsOnHole(
          holeLat + 0.0085, holeLng, holeLat, holeLng,
        ),
        isTrue,
      );
    });

    test('two provinces apart is measured, not guessed', () {
      final metres = SatelliteMeasureView.debugMetresBetween(
        officeLat, officeLng, holeLat, holeLng,
      );
      // The distance the app rendered as "1135 km".
      expect(metres, closeTo(1135000, 20000));
    });
  });
}
