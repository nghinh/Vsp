// Tests for imagery that turns up after the map is already open.
//
// The provider is fetched from the server after sign-in. A golfer who reaches
// the map before that request lands used to keep the "no imagery" answer for
// as long as the screen lived: the view read the provider once into a
// `late final`, and MapLibre reads `styleString` once, when it creates its
// platform view. So an operator who pasted a token into the server config saw
// nothing change until the app was restarted — which defeats the point of
// moving the provider off a build-time define in the first place.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/basemap/data/basemap_config_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_style_builder.dart';

SatelliteImageryConfig mapboxWith(String token) =>
    SatelliteImageryConfig.resolve(mapboxAccessToken: token);

void main() {
  tearDown(() => SatelliteImagery.overrideForTesting(null));

  group('the provider is observable', () {
    test('a listener hears the provider arrive', () {
      final seen = <SatelliteImageryProvider>[];
      void onChange() => seen.add(SatelliteImagery.listenable.value.provider);
      SatelliteImagery.listenable.addListener(onChange);
      addTearDown(() => SatelliteImagery.listenable.removeListener(onChange));

      SatelliteImagery.overrideForTesting(mapboxWith('pk.late'));

      // Without this the map has no way to know it should redraw.
      expect(seen, [SatelliteImageryProvider.mapbox]);
    });

    test('an unchanged fetch does not churn every map on screen', () {
      SatelliteImagery.overrideForTesting(mapboxWith('pk.same'));
      var notifications = 0;
      void onChange() => notifications++;
      SatelliteImagery.listenable.addListener(onChange);
      addTearDown(() => SatelliteImagery.listenable.removeListener(onChange));

      // The config is refetched on every sign-in. Rebuilding the map each time
      // would tear down a live platform view for nothing.
      SatelliteImagery.overrideForTesting(mapboxWith('pk.same'));

      expect(notifications, 0);
    });
  });

  group('the style key that forces a map rebuild', () {
    test('changes when imagery becomes available', () {
      final before = SatelliteImageryConfig.unavailable.styleKey;
      final after = mapboxWith('pk.token').styleKey;

      // MapLibre reads styleString once. A stable key would leave a live map
      // permanently styled for no imagery.
      expect(after, isNot(before));
    });

    test('is stable for the same provider', () {
      expect(mapboxWith('pk.a').styleKey, mapboxWith('pk.a').styleKey);
    });

    test('never contains the access token', () {
      // A widget key reaches diagnostics and error output.
      expect(mapboxWith('pk.secret-looking-token').styleKey,
          isNot(contains('pk.secret-looking-token')));
    });
  });

  group('the style built from a resolved provider', () {
    test('gains the raster source once a token exists', () {
      final before = SatelliteStyleBuilder.buildStyleMap(
        config: SatelliteImageryConfig.unavailable,
      );
      final after = SatelliteStyleBuilder.buildStyleMap(
        config: mapboxWith('pk.token'),
      );

      expect(
        (before['sources'] as Map)
            .containsKey(SatelliteStyleBuilder.satelliteSourceId),
        isFalse,
      );
      expect(
        (after['sources'] as Map)
            .containsKey(SatelliteStyleBuilder.satelliteSourceId),
        isTrue,
      );
    });
  });
}
