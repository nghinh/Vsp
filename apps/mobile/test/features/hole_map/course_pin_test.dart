// Today's flag on the hole map.
//
// The pin is a network read laid on top of a map that must work without one,
// so what is asserted is mostly what happens when it cannot be had: offline,
// unpublished, or expired all leave the hole exactly as the package drew it.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/data/course_pin_api.dart';
import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';
import 'package:vsp_mobile/core/network/api_client.dart';

class _StubClient extends ApiClient {
  _StubClient(this.body, {this.fail = false});

  final Object body;
  final bool fail;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    if (fail) throw Exception('offline');
    return body;
  }
}

void main() {
  group('CoursePinApi', () {
    test('reads the flag per hole, coordinates already decoded', () async {
      final api = CoursePinApi(
        apiClient: _StubClient([
          {
            'holeNumber': 7,
            'latitude': 21.03,
            'longitude': 105.85,
            'type': 'CURRENT',
            'confidence': 90,
            'expiresAt': null,
          },
        ]),
      );

      final pins = await api.forCourse('12');

      expect(pins.keys, [7]);
      expect(pins[7]!.latitude, 21.03);
      expect(pins[7]!.longitude, 105.85);
      // Published by the club, not guessed from a green polygon.
      expect(pins[7]!.source, PinSource.official);
      expect(pins[7]!.isExpired, isFalse);
    });

    test('a row missing its coordinates is skipped, not half-built', () async {
      final api = CoursePinApi(
        apiClient: _StubClient([
          {'holeNumber': 3, 'latitude': null, 'longitude': null},
          {'holeNumber': 4, 'latitude': 21.0, 'longitude': 105.0},
        ]),
      );

      final pins = await api.forCourse('12');

      expect(pins.keys, [4]);
    });

    test('a course nobody publishes for is an empty map', () async {
      final api = CoursePinApi(apiClient: _StubClient(const []));

      expect(await api.forCourse('12'), isEmpty);
    });

    test('an expired flag is recognisable as expired', () {
      final pin = PinEntity(
        holeId: '12-7',
        holeNumber: 7,
        latitude: 21.0,
        longitude: 105.0,
        source: PinSource.official,
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      // The bloc drops these rather than draw last week's flag as today's.
      expect(pin.isExpired, isTrue);
    });
  });
}
