// The arithmetic that replaced a platform call per pointer sample.
//
// Dragging a measured point used to ask the map to unproject the finger on
// every `onPanUpdate`. That is a MethodChannel round trip to Android, and
// pointer samples arrive faster than frames — up to 120 a second on the test
// phone — so the drag spent its time waiting on the platform thread while a
// queue of stale answers built up behind it.
//
// Rotation and tilt are both disabled on this map, which makes screen-to-world
// a plain linear scale over the span of one drag. So the scale is measured
// once, when the finger goes down, from two of the map's own answers 120 px
// apart — no tile-size convention is assumed, because the ratio between two
// answers from the same projection is right whatever the convention is. Every
// position after that is this class.
//
// What must not drift: the sign of the vertical axis. Screen y grows downward
// and latitude grows northward, so dragging a point *down* the screen must
// move it *south*. Getting that backwards would send every dragged point the
// wrong way and still look plausible in a unit test that only checked
// magnitude.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';

void main() {
  // Long Thành, roughly: 0.0000090 degrees of latitude per pixel is about a
  // metre a pixel, the order of magnitude at a hole-framing zoom.
  const anchor = DragAnchor(
    origin: Offset(200, 300),
    latitude: 10.8612399,
    longitude: 106.8960049,
    degreesPerPixelX: 0.0000091,
    degreesPerPixelY: -0.0000090,
  );

  test('the start position resolves to the point itself', () {
    final at = anchor.resolve(anchor.origin);

    expect(at.latitude, closeTo(anchor.latitude, 1e-12));
    expect(at.longitude, closeTo(anchor.longitude, 1e-12));
  });

  test('dragging down the screen moves the point south', () {
    final at = anchor.resolve(anchor.origin + const Offset(0, 100));

    expect(
      at.latitude,
      lessThan(anchor.latitude),
      reason: 'screen y grows downward, latitude grows northward',
    );
    expect(at.latitude, closeTo(anchor.latitude - 0.0009, 1e-9));
    expect(at.longitude, closeTo(anchor.longitude, 1e-12));
  });

  test('dragging right moves the point east', () {
    final at = anchor.resolve(anchor.origin + const Offset(100, 0));

    expect(at.longitude, greaterThan(anchor.longitude));
    expect(at.longitude, closeTo(anchor.longitude + 0.00091, 1e-9));
    expect(at.latitude, closeTo(anchor.latitude, 1e-12));
  });

  test('it is linear, so a drag and its reverse cancel', () {
    // The frames of a drag are resolved from the total offset since the start,
    // not accumulated increment by increment, so a wander that returns to
    // where it began returns the point to where it began.
    const wander = Offset(37, -212);
    final out = anchor.resolve(anchor.origin + wander);
    final back = anchor.resolve(anchor.origin);

    expect(out.latitude, isNot(closeTo(back.latitude, 1e-9)));
    expect(back.latitude, closeTo(anchor.latitude, 1e-12));
    expect(back.longitude, closeTo(anchor.longitude, 1e-12));
  });

  test('a diagonal drag moves both axes independently', () {
    final at = anchor.resolve(anchor.origin + const Offset(-50, 25));

    expect(at.longitude, closeTo(anchor.longitude - 0.000455, 1e-9));
    expect(at.latitude, closeTo(anchor.latitude - 0.000225, 1e-9));
  });
}
