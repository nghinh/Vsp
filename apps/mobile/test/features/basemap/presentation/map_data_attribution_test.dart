// Tests for the attribution the licences actually require.
//
// The ingest side was already right: fetch_osm.py stamps ODbL-1.0 and
// "OpenStreetMap contributors", detect_water_ndwi.py writes "Contains modified
// Copernicus Sentinel data", and V15 makes publisher NOT NULL. The chain broke
// between the database and the screen — ImageryAttribution was rendered in one
// place, the satellite measuring view, so it appeared only while Mapbox imagery
// was up. The vector hole map, which is where OSM-derived greens, bunkers,
// water and fairways are actually drawn, carried nothing. A grep for
// "copernicus" or "sentinel" across the whole app returned zero hits while 40
// Sentinel-2 water hazards shipped.
//
// These are legal obligations, so they are asserted rather than eyeballed: an
// attribution that quietly disappears in a refactor is the failure mode.

import 'package:course_package/course_package.dart' hide AccuracyClass;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/map_data_attribution.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
import 'package:vsp_mobile/features/settings/presentation/credits_screen.dart';
import 'package:vsp_mobile/features/settings/presentation/settings_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _StubRepository implements HoleMapRepository {
  final HoleMapEntity? holeMap;

  _StubRepository(this.holeMap);

  @override
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  }) async => holeMap;

  @override
  Future<CourseGeometryBundle?> getGeometryBundle({
    required String packageId,
    required String courseId,
  }) async => null;

  @override
  Future<List<CoursePackageManifest>> listPackages() async => const [];

  @override
  // No package on this fake device unless a test says otherwise.
  Future<String?> findPackageIdForCourse(String courseId) async => null;
}

// ─── Builders ───────────────────────────────────────────────────────────────

const _polygon = {
  'type': 'Feature',
  'geometry': {
    'type': 'Polygon',
    'coordinates': [
      [
        [106.7000, 10.7030],
        [106.7002, 10.7030],
        [106.7002, 10.7032],
        [106.7000, 10.7030],
      ],
    ],
  },
};

/// A surveyed hole, so the vector map is what gets drawn.
HoleMapEntity _hole({bool withWater = false}) => HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: 7,
  par: 4,
  provenance: const HoleDataProvenance(
    accuracyClass: AccuracyClass.classC,
    verificationStatus: VerificationStatus.verified,
  ),
  layers: {
    MapLayerType.green: const MapLayerEntity(
      type: MapLayerType.green,
      format: LayerGeometryFormat.geoJson,
      style: LayerStyle(),
      geoJson: _polygon,
    ),
    if (withWater)
      MapLayerType.water: const MapLayerEntity(
        type: MapLayerType.water,
        format: LayerGeometryFormat.geoJson,
        style: LayerStyle(),
        geoJson: _polygon,
      ),
  },
);

Future<void> _pumpHole(WidgetTester tester, {required bool withWater}) async {
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepositoryProvider<HoleMapRepository>(
        create: (_) => _StubRepository(_hole(withWater: withWater)),
        child: const HoleMapScreen(
          packageId: 'package-1',
          courseId: 'course-1',
          courseName: 'Test course',
          holeNumber: 7,
          imageryConfig: SatelliteImageryConfig.unavailable,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  // The map opens on satellite now, so a test about the vector map has to ask
  // for it — the same deliberate switch a golfer makes.
  setUp(() => BasemapPreference.choose(BasemapMode.courseMap));
  tearDown(BasemapPreference.resetForTesting);

  group('the vector hole map', () {
    testWidgets('credits OpenStreetMap, which it never used to', (
      tester,
    ) async {
      await _pumpHole(tester, withWater: false);

      // ODbL §4.3: the licence notice travels with public use of the derived
      // database. This map draws OSM-derived shapes and showed nothing.
      expect(
        find.byType(MapDataAttribution, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('OpenStreetMap', skipOffstage: false),
        findsWidgets,
      );
      expect(
        find.textContaining('ODbL', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('credits Copernicus on a hole with water', (tester) async {
      await _pumpHole(tester, withWater: true);

      // 40 of 45 water hazards are Sentinel-2 NDWI derivations and the notice
      // their terms require appeared nowhere in the app.
      expect(
        find.textContaining('Copernicus Sentinel', skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('does not credit Copernicus on a hole with no water', (
      tester,
    ) async {
      await _pumpHole(tester, withWater: false);

      // Crediting a source a screen does not use is noise, and noise is what
      // gets attribution deleted later.
      expect(
        find.textContaining('Copernicus', skipOffstage: false),
        findsNothing,
      );
    });
  });

  group('the credits screen', () {
    testWidgets('is reachable from settings', (tester) async {
      await tester.pumpWidget(
        BlocProvider<LocaleCubit>(
          create: (_) => LocaleCubit(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.creditsTitle));
      await tester.pumpAndSettle();

      expect(find.byType(CreditsScreen), findsOneWidget);
    });

    testWidgets('states both data obligations and reaches the code licences', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CreditsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('OpenStreetMap'), findsWidgets);
      expect(find.textContaining('Copernicus Sentinel'), findsWidgets);

      // showLicensePage is how Flutter's generated NOTICES becomes reachable.
      // It was never called anywhere, so every bundled package's licence
      // shipped inside the binary with no way to read it.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.creditsOpenSourceLicences));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('says all of it in Vietnamese too', (tester) async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final vi = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(en.creditsOpenStreetMapBody, isNot(vi.creditsOpenStreetMapBody));
      expect(en.creditsCopernicusBody, isNot(vi.creditsCopernicusBody));
      expect(en.creditsDataQualityNote, isNot(vi.creditsDataQualityNote));
    });
  });
}
