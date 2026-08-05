// ImageryAttribution Widget Tests — VSP Mobile App
//
// The provider's attribution is a licence condition, not decoration. These
// tests exist so it cannot be dropped by accident during a redesign.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/imagery_attribution.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );
  }

  final mapbox = SatelliteImageryConfig.resolve(
    mapboxAccessToken: 'pk.test-token',
  );

  testWidgets('shows the Mapbox logo and every required link', (tester) async {
    final opened = <Uri>[];

    await tester.pumpWidget(
      wrap(
        ImageryAttribution(
          config: mapbox,
          onOpenUrl: (url) async {
            opened.add(url);
            return true;
          },
        ),
      ),
    );

    // The logo asset itself — Mapbox require the mark, not just the words.
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/imagery/mapbox-logo.png');

    expect(find.text('© Mapbox'), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
    expect(find.text('Improve this map'), findsOneWidget);
  });

  testWidgets('each attribution link opens the documented URL', (tester) async {
    final opened = <Uri>[];

    await tester.pumpWidget(
      wrap(
        ImageryAttribution(
          config: mapbox,
          onOpenUrl: (url) async {
            opened.add(url);
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('© Mapbox'));
    await tester.tap(find.text('© OpenStreetMap'));
    await tester.tap(find.text('Improve this map'));
    await tester.pump();

    expect(opened, [
      ImageryAttribution.mapboxUrl,
      ImageryAttribution.openStreetMapUrl,
      ImageryAttribution.improveMapUrl,
    ]);
    expect(opened[0].host, 'www.mapbox.com');
    expect(opened[1].host, 'www.openstreetmap.org');
  });

  testWidgets('operator imagery shows its own credit and no Mapbox logo',
      (tester) async {
    final custom = SatelliteImageryConfig.resolve(
      customTileUrl: 'https://tiles.example.vn/{z}/{x}/{y}.jpg',
      customAttribution: '© Example Imagery',
    );

    await tester.pumpWidget(wrap(ImageryAttribution(config: custom)));

    expect(find.text('© Example Imagery'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders nothing when no imagery is configured', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ImageryAttribution(config: SatelliteImageryConfig.unavailable),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('Mapbox'), findsNothing);
  });
}
