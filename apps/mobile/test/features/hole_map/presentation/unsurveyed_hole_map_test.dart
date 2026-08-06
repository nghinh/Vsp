// Widget tests for what the Map tab does on a hole we never digitised.
//
// 61 of roughly 900 holes carry surveyed geometry, and most Vietnamese courses
// have no downloaded package at all. That case used to end in HoleMapError and
// an empty state — the map refusing to help precisely where the golfer has the
// least data. It now opens satellite imagery with the measuring tool live,
// because the photograph under their finger is the real course even where our
// vector data is not, and it labels itself unsurveyed while it does.
//
// The one thing worse than an empty map is a blank one presented as a map, so
// a build compiled without an imagery provider says exactly that instead.
// Satellite is deliberately disabled without a token (see
// SatelliteImageryConfig) and no fallback tiles are pulled from providers we
// have no licence for.
//
// Where a hole does have geometry, nothing changes: it still opens as the
// vector strategic map.

import 'package:course_package/course_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _NoLocationService implements LocationService {
  @override
  Stream<QualifiedLocation> get locationStream => const Stream.empty();

  @override
  QualifiedLocation? get lastLocation => null;

  @override
  Future<QualifiedLocation> getCurrentLocation() async =>
      QualifiedLocation.unavailable();

  @override
  void start() {}

  @override
  void stop() {}

  @override
  Future<bool> isLocationAvailable() async => false;

  @override
  Duration get stationaryInterval => const Duration(seconds: 30);

  @override
  Duration get activeInterval => const Duration(seconds: 5);

  @override
  void dispose() {}
}

class _StubHoleMapRepository implements HoleMapRepository {
  final HoleMapEntity? holeMap;

  _StubHoleMapRepository(this.holeMap);

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
}

// ─── Builders ───────────────────────────────────────────────────────────────

/// A build compiled with an operator's own licensed imagery endpoint.
final _imageryAvailable = SatelliteImageryConfig.resolve(
  customTileUrl: 'https://tiles.example.vn/{z}/{x}/{y}.jpg',
  customAttribution: '© Example imagery',
);

/// A hole the course package knows about but carries no shapes for. Cart paths
/// are not strategy — a golfer cannot plan a shot from one.
HoleMapEntity _holeWithoutShapes() => const HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: 7,
  par: 4,
  layers: {
    MapLayerType.cartPath: MapLayerEntity(
      type: MapLayerType.cartPath,
      format: LayerGeometryFormat.geoJson,
      style: LayerStyle(),
      geoJson: {'type': 'FeatureCollection', 'features': []},
    ),
  },
);

/// A hole that really was surveyed.
HoleMapEntity _surveyedHole() => const HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: 7,
  par: 4,
  layers: {
    MapLayerType.green: MapLayerEntity(
      type: MapLayerType.green,
      format: LayerGeometryFormat.geoJson,
      style: LayerStyle(),
      geoJson: {
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
      },
    ),
  },
);

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  String? packageId,
  HoleMapEntity? holeMap,
  SatelliteImageryConfig? imageryConfig,
  Locale locale = const Locale('en'),
}) async {
  // 480 × 1000 dp. Wider than the 360 dp phone this is really aimed at,
  // because the test font is a fixed-width stand-in roughly 1.7× the width of
  // the one the app ships — asserting layout at 360 dp here would be asserting
  // against a device nobody owns. Layout regressions at real widths belong in
  // a golden test, not here.
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepositoryProvider<HoleMapRepository>(
        create: (_) => _StubHoleMapRepository(holeMap),
        child: HoleMapScreen(
          packageId: packageId,
          courseId: 'course-1',
          courseName: 'Test course',
          holeNumber: 7,
          locationService: _NoLocationService(),
          imageryConfig: imageryConfig ?? SatelliteImageryConfig.unavailable,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return AppLocalizations.delegate.load(locale);
}

void _expectRendered(String text) {
  expect(find.text(text, skipOffstage: false), findsWidgets, reason: text);
}

void _expectSatelliteMeasuring() {
  expect(find.byType(SatelliteMeasureView, skipOffstage: false), findsOneWidget);
  expect(find.byType(NoGeometryBanner, skipOffstage: false), findsOneWidget);
}

void main() {
  group('a hole with no surveyed geometry', () {
    testWidgets('with no package at all, opens satellite and measuring', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        packageId: null,
        imageryConfig: _imageryAvailable,
      );

      _expectSatelliteMeasuring();
      _expectRendered(l10n.holeNoGeometryBadge);
      _expectRendered(l10n.holeNoGeometryTitle);
      _expectRendered(l10n.holeNoGeometryBody);
    });

    testWidgets('with a package that carries nothing for it, the same', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: null,
        imageryConfig: _imageryAvailable,
      );

      _expectSatelliteMeasuring();
      _expectRendered(l10n.holeNoGeometryTitle);
    });

    testWidgets('with a package holding no strategic shapes, the same again', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _holeWithoutShapes(),
        imageryConfig: _imageryAvailable,
      );

      _expectSatelliteMeasuring();
      _expectRendered(l10n.holeNoGeometryTitle);
    });
  });

  group('a build with no imagery provider', () {
    testWidgets('explains itself rather than drawing a blank map', (
      tester,
    ) async {
      final l10n = await _pump(tester, packageId: null);

      _expectRendered(l10n.holeNoGeometryNoImageryTitle);
      _expectRendered(l10n.holeNoGeometryNoImageryBody);
      // No tiles are pulled from anywhere we have no licence for, and no
      // empty map is offered in their place.
      expect(
        find.byType(SatelliteMeasureView, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('says the same for a package that carries nothing', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _holeWithoutShapes(),
      );

      _expectRendered(l10n.holeNoGeometryNoImageryTitle);
    });

    for (final locale in const [Locale('en'), Locale('vi')]) {
      testWidgets('takes its wording from l10n in ${locale.languageCode}', (
        tester,
      ) async {
        final l10n = await _pump(tester, packageId: null, locale: locale);

        _expectRendered(l10n.holeNoGeometryNoImageryTitle);
        _expectRendered(l10n.holeNoGeometryNoImageryBody);
      });
    }

    testWidgets('and the two languages really differ', (tester) async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final vi = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(
        en.holeNoGeometryNoImageryTitle,
        isNot(vi.holeNoGeometryNoImageryTitle),
      );
      expect(
        en.holeNoGeometryNoImageryBody,
        isNot(vi.holeNoGeometryNoImageryBody),
      );
    });
  });

  group('a hole that was surveyed', () {
    testWidgets('still opens as the vector strategic map', (tester) async {
      await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _surveyedHole(),
        imageryConfig: _imageryAvailable,
      );

      // Real geometry beats a photograph: the measuring fallback stays out of
      // the way and the unsurveyed banner is not shown.
      expect(
        find.byType(SatelliteMeasureView, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(NoGeometryBanner, skipOffstage: false), findsNothing);
    });
  });
}
