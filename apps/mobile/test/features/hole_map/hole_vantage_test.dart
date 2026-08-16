// Where the numbers on the hole map are measured from.
//
// Opening hole 1 of Long Biên from a flat in Hanoi read "to the pin: 6.1 mi",
// and every hazard on the screen carried the same six miles. True, and no
// use to anybody: a golfer who is not on the hole is looking at it, and what
// they want to see is the shot they will face from the tee.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_vantage.dart';

void main() {
  const tee = LatLng(latitude: 21.03752, longitude: 105.89444);
  const green = LatLng(latitude: 21.03506, longitude: 105.89110);

  test('a golfer standing on the tee is measured from where they stand', () {
    const onTee = LatLng(latitude: 21.03750, longitude: 105.89440);

    expect(HoleVantage.measuringPoint(golfer: onTee, tee: tee, green: green),
        onTee);
  });

  test('a golfer halfway down the hole is measured from where they stand', () {
    const fairway = LatLng(latitude: 21.03630, longitude: 105.89280);

    expect(HoleVantage.measuringPoint(golfer: fairway, tee: tee, green: green),
        fairway);
  });

  /// The case from the screenshot: ten kilometres away, at home.
  test('a golfer nowhere near the course is measured from the tee', () {
    const atHome = LatLng(latitude: 21.0100, longitude: 105.8100);

    expect(HoleVantage.measuringPoint(golfer: atHome, tee: tee, green: green),
        tee);
  });

  /// A golfer walking in from the previous green is still playing golf.
  test('a few hundred metres off the hole still counts as on it', () {
    const nextTeeOver = LatLng(latitude: 21.04100, longitude: 105.89444);

    expect(HoleVantage.isOnHole(golfer: nextTeeOver, tee: tee, green: green),
        isTrue);
  });

  test('with no fix the tee is the vantage', () {
    expect(HoleVantage.measuringPoint(golfer: null, tee: tee, green: green),
        tee);
  });

  /// A hole with neither a tee nor a green coordinate has no distances to
  /// show, and inventing one is worse than the blank space.
  test('with neither a fix nor a tee there is nothing to measure from', () {
    expect(HoleVantage.measuringPoint(golfer: null, tee: null, green: null),
        isNull);
  });

  /// A hole this project never got coordinates for still has a golfer on it,
  /// and their own position is the only thing left to measure from.
  test('a fix with no hole coordinates is used as it is', () {
    const somewhere = LatLng(latitude: 21.0100, longitude: 105.8100);

    expect(
        HoleVantage.measuringPoint(golfer: somewhere, tee: null, green: null),
        somewhere);
  });
}
