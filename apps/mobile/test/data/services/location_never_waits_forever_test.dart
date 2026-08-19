// Asking for location permission has a clock on it.
//
// Found by the screen-by-screen sweep: it opened the "Gần đây" tab of the
// course list, waited twenty-five seconds, and photographed it still turning
// on "Đang tìm sân gần bạn…". No error, no empty state, no way out but leaving
// the screen.
//
// The bloc above it says, in a comment: "Never leave the tab spinning: a
// denied/disabled/timed-out fix emits an error state so the UI can prompt the
// user to enable location and retry." It kept that promise for the fix, which
// carries a ten second limit, and not for the permission request in front of
// it — and `requestPermission()` resolves when the golfer answers a system
// dialog, which there is no rule saying they ever will. They can leave it on
// screen; the platform channel can stall. The await simply never completes,
// and everything waiting on it waits too.
//
// Unanswered is not granted. A golfer who ignores the dialog now gets the same
// answer as one who says no, and the screen behind it moves on to something it
// can act on.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:vsp_mobile/data/services/location_service_impl.dart';

/// A platform that never answers, which is the whole point.
class _SilentGeolocator extends GeolocatorPlatform {
  _SilentGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.denied,
    this.answersRequest = false,
    this.answersFix = false,
  });

  final bool serviceEnabled;
  final LocationPermission permission;

  /// When false, `requestPermission()` returns a future that never completes —
  /// a dialog nobody ever taps.
  final bool answersRequest;

  /// When false, `getCurrentPosition()` never completes either.
  final bool answersFix;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() {
    if (answersRequest) return Future.value(LocationPermission.whileInUse);
    return Completer<LocationPermission>().future;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    if (answersFix) {
      return Future.value(
        Position(
          latitude: 21.0384,
          longitude: 105.8920,
          timestamp: DateTime.fromMillisecondsSinceEpoch(0),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
    }
    return Completer<Position>().future;
  }
}

void main() {
  test('the permission request gives up rather than hanging', () {
    fakeAsync((async) {
      final service = LocationServiceImpl(
        geolocator: _SilentGeolocator(answersRequest: false),
      );

      bool? answer;
      service.isLocationAvailable().then((value) => answer = value);

      // A minute in. Without the timeout this is still null, for ever, and so
      // is the tab that asked.
      async.elapse(const Duration(seconds: 59));
      expect(
        answer,
        isFalse,
        reason: 'an unanswered dialog has to resolve to "no" eventually, or '
            'the screen behind it spins until the golfer leaves it',
      );
    });
  });

  test('and answers "yes" the moment permission is actually given', () {
    fakeAsync((async) {
      final service = LocationServiceImpl(
        geolocator: _SilentGeolocator(answersRequest: true),
      );

      bool? answer;
      service.isLocationAvailable().then((value) => answer = value);
      async.elapse(const Duration(milliseconds: 100));

      expect(answer, isTrue);
    });
  });

  test('a fix that never arrives resolves to unavailable', () {
    fakeAsync((async) {
      final service = LocationServiceImpl(
        geolocator: _SilentGeolocator(
          permission: LocationPermission.whileInUse,
          answersFix: false,
        ),
      );

      QualifiedLocationLike? result;
      service
          .getCurrentLocation()
          .then((value) => result = QualifiedLocationLike(value.source.name));

      async.elapse(const Duration(seconds: 59));
      expect(result?.source, 'unavailable');
    });
  });

  test('and a fix that does arrive is used', () {
    fakeAsync((async) {
      final service = LocationServiceImpl(
        geolocator: _SilentGeolocator(
          permission: LocationPermission.whileInUse,
          answersFix: true,
        ),
      );

      double? lat;
      service.getCurrentLocation().then((value) => lat = value.latitude);
      async.elapse(const Duration(milliseconds: 100));

      expect(lat, closeTo(21.0384, 1e-6));
    });
  });
}

/// Tiny holder so the test reads without importing the whole value object.
class QualifiedLocationLike {
  QualifiedLocationLike(this.source);
  final String source;
}
