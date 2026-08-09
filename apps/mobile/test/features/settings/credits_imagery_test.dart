// Who the credits screen says is supplying the satellite imagery.
//
// It used to say "© Mapbox © OpenStreetMap", as a constant, with a link to
// Mapbox's terms of service. Then the imagery provider moved from a build-time
// define to a server-side setting, the deployment was pointed at Esri, and the
// two attribution surfaces started disagreeing: the map footer read "Powered by
// Esri — Esri, Maxar, Earthstar Geographics" while this screen — the one that
// exists precisely to discharge the attribution obligation — credited a company
// whose imagery was not on screen.
//
// That is a licence problem pointing both ways: an uncredited provider whose
// terms require credit, and a credited provider whose terms we are invoking
// without using their service. Neither is fixed by editing the string, because
// the provider is a runtime setting. These pin that it follows the setting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/settings/presentation/credits_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

const _esri = SatelliteImageryConfig(
  provider: SatelliteImageryProvider.custom,
  tileUrlTemplate: 'https://tiles.example.vn/{z}/{y}/{x}',
  attributionText: 'Powered by Esri — Esri, Maxar, Earthstar Geographics',
  requiresMapboxLogo: false,
  tileSize: 256,
  maxZoom: 19,
);

const _mapbox = SatelliteImageryConfig(
  provider: SatelliteImageryProvider.mapbox,
  tileUrlTemplate: 'https://api.mapbox.com/{z}/{x}/{y}',
  attributionText: '© Mapbox © OpenStreetMap',
  requiresMapboxLogo: true,
  tileSize: 512,
  maxZoom: 22,
);

Future<AppLocalizations> _pump(
  WidgetTester tester,
  SatelliteImageryConfig imagery,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CreditsScreen(imagery: imagery, onOpenUrl: (_) async => true),
    ),
  );
  await tester.pump();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('credits the operator actually serving the tiles', (
    tester,
  ) async {
    final l10n = await _pump(tester, _esri);

    expect(find.text(_esri.attributionText), findsOneWidget);
    expect(
      find.text('© Mapbox © OpenStreetMap'),
      findsNothing,
      reason: 'Mapbox is not serving this deployment and must not be credited',
    );
    expect(find.text(l10n.creditsImageryProviderBody), findsOneWidget);
  });

  testWidgets('offers no licence link it cannot honour', (tester) async {
    // The operator supplies a credit line, not a terms URL. Linking to
    // Mapbox's terms for Esri imagery would be the same wrong claim in a
    // different place.
    await _pump(tester, _esri);

    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text(_esri.attributionText),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNull);
    expect(tile.trailing, isNull);
  });

  testWidgets('credits Mapbox, with its terms, when Mapbox is serving', (
    tester,
  ) async {
    final l10n = await _pump(tester, _mapbox);

    expect(find.text('© Mapbox © OpenStreetMap'), findsOneWidget);
    expect(find.text(l10n.creditsMapboxBody), findsOneWidget);

    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('© Mapbox © OpenStreetMap'),
        matching: find.byType(ListTile),
      ),
    );
    expect(
      tile.onTap,
      isNotNull,
      reason: 'Mapbox requires a link to its terms',
    );
  });

  testWidgets('says there is no imagery rather than crediting nobody', (
    tester,
  ) async {
    // A build with no provider configured is a real, supported state — the
    // measuring tool works over a plain canvas. Leaving the section blank
    // would read as an unfinished screen.
    final l10n = await _pump(tester, SatelliteImageryConfig.unavailable);

    expect(find.text(l10n.creditsImageryNoneTitle), findsOneWidget);
    expect(find.text(l10n.creditsImageryNoneBody), findsOneWidget);
  });

  testWidgets('always credits OpenStreetMap, which supplies the geometry', (
    tester,
  ) async {
    // The vector shapes are ODbL regardless of who supplies the pictures, so
    // this entry is not conditional on the imagery provider.
    for (final imagery in [
      _esri,
      _mapbox,
      SatelliteImageryConfig.unavailable,
    ]) {
      final l10n = await _pump(tester, imagery);
      expect(find.text(l10n.creditsOpenStreetMapBody), findsOneWidget);
    }
  });
}
