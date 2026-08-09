// Tests for resolving the satellite provider at runtime.
//
// SatelliteImageryConfig reads --dart-define values compiled into the binary.
// Nothing in this repository passes those defines, so no build that has ever
// existed shows imagery — and a define cannot be changed on a phone that
// already has the app, so switching satellite on for a pilot meant shipping a
// release. The server now supplies the same three values.
//
// Two rules are load-bearing here. A build that WAS given a provider keeps it:
// an operator who compiled in their own licensed orthophotos made a decision,
// and a server must not silently replace it. And a failed fetch keeps whatever
// the device had, because the moment this matters most is a golfer on the first
// tee with one bar of signal.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/features/basemap/data/basemap_config_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';

/// An ApiClient whose one request either answers or throws.
class _StubApiClient implements ApiClient {
  final Object? answer;
  final bool shouldThrow;
  int calls = 0;

  _StubApiClient({this.answer, this.shouldThrow = false});

  @override
  Future<dynamic> request({
    required String path,
    required HttpMethod method,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    String? idempotencyKey,
    Map<String, String>? headers,
    bool retryOnUnauthorized = true,
  }) async {
    calls++;
    if (shouldThrow) throw Exception('no signal');
    return answer;
  }

  @override
  void setAccessToken(String? token) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SatelliteImagery.overrideForTesting(null);
  });

  tearDown(() => SatelliteImagery.overrideForTesting(null));

  BasemapConfigService serviceWith(_StubApiClient client) =>
      BasemapConfigService(apiClient: client);

  group('fetching the provider', () {
    test('a Mapbox token from the server resolves to Mapbox imagery', () async {
      final service = serviceWith(
        _StubApiClient(
          answer: {
            'mapboxAccessToken': 'pk.test',
            'satelliteTileUrl': '',
            'satelliteAttribution': '',
          },
        ),
      );

      final values = await service.refresh();

      expect(values!.resolve().provider, SatelliteImageryProvider.mapbox);
      expect(values.resolve().isAvailable, isTrue);
    });

    test('operator imagery without attribution is refused', () async {
      final service = serviceWith(
        _StubApiClient(
          answer: {
            'mapboxAccessToken': '',
            'satelliteTileUrl': 'https://tiles.example.vn/{z}/{x}/{y}.jpg',
            'satelliteAttribution': '',
          },
        ),
      );

      // Inherited from SatelliteImageryConfig.resolve rather than re-decided
      // here: imagery we cannot credit is imagery we do not display, whichever
      // path configured it.
      expect((await service.refresh())!.resolve().isAvailable, isFalse);
    });

    test('an unconfigured server means no imagery, not an error', () async {
      final service = serviceWith(
        _StubApiClient(
          answer: {
            'mapboxAccessToken': '',
            'satelliteTileUrl': '',
            'satelliteAttribution': '',
          },
        ),
      );

      expect((await service.refresh())!.resolve(),
          SatelliteImageryConfig.unavailable);
    });
  });

  group('when the network is not there', () {
    test('the cached provider survives a failed fetch', () async {
      SharedPreferences.setMockInitialValues({
        'vsp.basemap.config.v1': jsonEncode({
          'mapboxAccessToken': 'pk.cached',
          'satelliteTileUrl': '',
          'satelliteAttribution': '',
        }),
      });

      final values = await serviceWith(
        _StubApiClient(shouldThrow: true),
      ).refresh();

      // The first tee is where signal is worst and imagery matters most.
      expect(values!.mapboxAccessToken, 'pk.cached');
    });

    test('no cache and no network is simply no imagery', () async {
      final values = await serviceWith(
        _StubApiClient(shouldThrow: true),
      ).refresh();

      expect(values, isNull);
    });
  });

  group('revocation', () {
    test('switching imagery off at the server clears the cache', () async {
      SharedPreferences.setMockInitialValues({
        'vsp.basemap.config.v1': jsonEncode({
          'mapboxAccessToken': 'pk.revoked',
          'satelliteTileUrl': '',
          'satelliteAttribution': '',
        }),
      });
      final service = serviceWith(
        _StubApiClient(
          answer: {
            'mapboxAccessToken': '',
            'satelliteTileUrl': '',
            'satelliteAttribution': '',
          },
        ),
      );

      await service.refresh();

      // Otherwise a revoked token keeps being requested from every device that
      // ever cached one, and the operator's "off" switch does nothing.
      expect(await service.cached(), isNull);
    });
  });

  group('the provider the map reads', () {
    test('load picks up what the server says', () async {
      await SatelliteImagery.load(
        serviceWith(
          _StubApiClient(
            answer: {
              'mapboxAccessToken': 'pk.loaded',
              'satelliteTileUrl': '',
              'satelliteAttribution': '',
            },
          ),
        ),
      );

      expect(SatelliteImagery.current.provider, SatelliteImageryProvider.mapbox);
    });

    test('a failure leaves the app with a state the map handles', () async {
      await SatelliteImagery.load(serviceWith(_StubApiClient(shouldThrow: true)));

      // Unavailable is not an error path — it is what ~900 of our holes look
      // like, and the measuring tool works over it.
      expect(SatelliteImagery.current, SatelliteImageryConfig.unavailable);
    });

    test('a build with no compiled-in provider does ask the server', () async {
      final client = _StubApiClient(
        answer: {
          'mapboxAccessToken': 'pk.x',
          'satelliteTileUrl': '',
          'satelliteAttribution': '',
        },
      );

      await SatelliteImagery.load(serviceWith(client));

      // This suite runs without MAPBOX_ACCESS_TOKEN defined, which is also how
      // every build in this repository is produced.
      expect(SatelliteImagery.isFixedByBuild, isFalse);
      expect(client.calls, 1);
    });
  });
}
