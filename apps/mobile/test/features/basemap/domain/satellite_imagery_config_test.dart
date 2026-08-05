// SatelliteImageryConfig Unit Tests — VSP Mobile App
//
// Imagery licensing is not a detail we can get wrong, so it is tested:
// - No configuration means NO tiles, not a fallback to someone else's server
// - Mapbox tiles carry the access token and demand the Mapbox logo
// - An operator-supplied endpoint must come with attribution or it is refused
// - The token never leaks into a log line

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';

void main() {
  group('unconfigured build', () {
    test('is unavailable rather than falling back to unlicensed tiles', () {
      final config = SatelliteImageryConfig.resolve();

      expect(config.provider, SatelliteImageryProvider.none);
      expect(config.isAvailable, isFalse);
      expect(config.tileUrlTemplate, isEmpty);
    });

    test('blank and whitespace-only values count as unconfigured', () {
      expect(
        SatelliteImageryConfig.resolve(mapboxAccessToken: '   ').isAvailable,
        isFalse,
      );
      expect(
        SatelliteImageryConfig.resolve(customTileUrl: '  ').isAvailable,
        isFalse,
      );
    });
  });

  group('Mapbox', () {
    final config = SatelliteImageryConfig.resolve(
      mapboxAccessToken: 'pk.test-token',
    );

    test('builds a Raster Tiles API template for mapbox.satellite', () {
      expect(config.provider, SatelliteImageryProvider.mapbox);
      expect(config.tileUrlTemplate, startsWith('https://api.mapbox.com/v4/'));
      expect(config.tileUrlTemplate, contains('mapbox.satellite'));
      expect(config.tileUrlTemplate, contains('{z}/{x}/{y}'));
      expect(config.tileUrlTemplate, contains('access_token=pk.test-token'));
    });

    test('requests high-DPI 512 px tiles', () {
      expect(config.tileUrlTemplate, contains('@2x'));
      expect(config.tileSize, 512);
    });

    test('requires the Mapbox logo and the mandated attribution text', () {
      expect(config.requiresMapboxLogo, isTrue);
      expect(config.attributionText, contains('Mapbox'));
      expect(config.attributionText, contains('OpenStreetMap'));
    });

    test('never uses a Google endpoint', () {
      expect(config.tileUrlTemplate, isNot(contains('google')));
      expect(config.tileUrlTemplate, isNot(contains('googleapis')));
    });

    test('redacts the token in toString', () {
      expect(config.toString(), isNot(contains('pk.test-token')));
      expect(config.toString(), contains('redacted'));
      expect(config.toString(), contains('mapbox'));
    });
  });

  group('operator-supplied imagery', () {
    test('wins over Mapbox so licensed local imagery is preferred', () {
      final config = SatelliteImageryConfig.resolve(
        mapboxAccessToken: 'pk.test-token',
        customTileUrl: 'https://tiles.example.vn/{z}/{x}/{y}.jpg',
        customAttribution: '© Example Imagery',
      );

      expect(config.provider, SatelliteImageryProvider.custom);
      expect(config.tileUrlTemplate, 'https://tiles.example.vn/{z}/{x}/{y}.jpg');
      expect(config.attributionText, '© Example Imagery');
      expect(config.requiresMapboxLogo, isFalse);
    });

    test('is refused without attribution — we credit what we display', () {
      final config = SatelliteImageryConfig.resolve(
        customTileUrl: 'https://tiles.example.vn/{z}/{x}/{y}.jpg',
      );

      expect(config.provider, SatelliteImageryProvider.none);
      expect(config.isAvailable, isFalse);
    });

    test('falls back to Mapbox when the custom endpoint is incomplete', () {
      final config = SatelliteImageryConfig.resolve(
        mapboxAccessToken: 'pk.test-token',
        customTileUrl: 'https://tiles.example.vn/{z}/{x}/{y}.jpg',
      );

      expect(config.provider, SatelliteImageryProvider.mapbox);
    });
  });

  test('fromEnvironment is unavailable unless a token is baked in', () {
    // Tests run without --dart-define, so this is the shipped-without-a-key
    // behaviour: the app says so instead of silently misbehaving.
    expect(SatelliteImageryConfig.fromEnvironment().isAvailable, isFalse);
  });

  test('equality follows value semantics', () {
    expect(
      SatelliteImageryConfig.resolve(mapboxAccessToken: 'pk.a'),
      SatelliteImageryConfig.resolve(mapboxAccessToken: 'pk.a'),
    );
    expect(
      SatelliteImageryConfig.resolve(mapboxAccessToken: 'pk.a'),
      isNot(SatelliteImageryConfig.resolve(mapboxAccessToken: 'pk.b')),
    );
  });
}
