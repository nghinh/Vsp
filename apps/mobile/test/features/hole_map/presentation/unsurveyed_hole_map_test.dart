// Widget tests for what the Map tab does on a hole we never digitised.
//
// 61 of roughly 900 holes carry surveyed geometry, and most Vietnamese courses
// have no downloaded package at all. That case used to end in HoleMapError and
// an empty state — the map refusing to help precisely where the golfer has the
// least data. It now opens satellite imagery with the measuring tool live,
// because the photograph under their finger is the real course even where our
// vector data is not, and it labels itself unsurveyed while it does.
//
// A build compiled without an imagery provider pulls no tiles — satellite is
// deliberately disabled without a token (see SatelliteImageryConfig) and no
// fallback tiles come from providers we have no licence for. It used to stop
// there and show an explanation screen, which since every hole was relabelled
// unverified made that screen the whole Map tab. The measuring tool needs GPS,
// not pictures, so it is now offered over a plain canvas instead, with wording
// that promises no photograph.
//
// Where a hole has geometry somebody actually verified, nothing changes: it
// still opens as the vector strategic map. Geometry alone is not enough —
// every hole in the database carries shapes derived from invented coordinates.

import 'package:course_package/course_package.dart' hide AccuracyClass;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/imagery_attribution.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/measure_panel.dart';
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

  @override
  // No package on this fake device unless a test says otherwise.
  Future<String?> findPackageIdForCourse(String courseId) async => null;
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

/// A hole exactly as the database now holds all 900 of them: strategic shapes
/// derived from tee and green points that were generated arithmetically, and a
/// provenance saying so. The shape is real GeoJSON; the coordinates under it
/// are invented, which is why it must not be drawn as a strategic map.
HoleMapEntity _syntheticHole() => const HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: 7,
  par: 4,
  provenance: HoleDataProvenance(
    accuracyClass: AccuracyClass.classD,
    verificationStatus: VerificationStatus.unverified,
    source: 'synthetic:seed-arithmetic',
  ),
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
    MapLayerType.fairway: MapLayerEntity(
      type: MapLayerType.fairway,
      format: LayerGeometryFormat.geoJson,
      style: LayerStyle(),
      geoJson: {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [106.7000, 10.7000],
            [106.7001, 10.7031],
          ],
        },
      },
    ),
  },
);

/// A hole that really was surveyed — shapes *and* a provenance that says
/// somebody digitised them and somebody checked. Both halves are required: a
/// derived polygon around invented coordinates is not a survey.
HoleMapEntity _surveyedHole() => const HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: 7,
  par: 4,
  provenance: HoleDataProvenance(
    accuracyClass: AccuracyClass.classC,
    verificationStatus: VerificationStatus.verified,
  ),
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
  // The basemap choice is remembered for the app session, so a golfer who picks
  // satellite on the 1st still has it on the 2nd. That makes it shared state
  // between tests: one test tapping the toggle changed which map the next test
  // opened on.
  // The map opens on satellite now. Tests about the vector strategic map ask
  // for it explicitly, which is the same deliberate switch a golfer makes.
  setUp(BasemapPreference.resetForTesting);
  tearDown(BasemapPreference.resetForTesting);

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
    testWidgets('still hands the golfer the measuring tool', (tester) async {
      final l10n = await _pump(tester, packageId: null);

      // The ruler and the picture are separate things. No tiles are pulled
      // from a provider we have no licence for, but the measuring tool runs
      // on GPS and geodesy, so it is still on screen with its own readout.
      _expectSatelliteMeasuring();
      expect(find.byType(MeasurePanel, skipOffstage: false), findsOneWidget);
      _expectRendered(l10n.holeNoGeometryBadge);
      _expectRendered(l10n.holeNoGeometryBodyNoImagery);
    });

    testWidgets('does not promise imagery it cannot fetch', (tester) async {
      final l10n = await _pump(tester, packageId: null);

      // The imagery wording and the Mapbox credit both belong to a build that
      // actually has tiles.
      expect(
        find.text(l10n.holeNoGeometryBody, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.text(l10n.measureEmptyBody, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(ImageryAttribution, skipOffstage: false), findsNothing);
      _expectRendered(l10n.measureWithoutImagery);
      _expectRendered(l10n.measureEmptyBodyNoImagery);
    });

    testWidgets('says the same for a package that carries nothing', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _holeWithoutShapes(),
      );

      _expectSatelliteMeasuring();
      _expectRendered(l10n.holeNoGeometryBodyNoImagery);
    });

    testWidgets('and so does a package whose shapes were never verified', (
      tester,
    ) async {
      // The case that now covers all 900 holes in the database: geometry
      // exists, but it was synthesised from tee and green points nobody
      // checked. A polygon drawn around invented coordinates is not a survey,
      // so the vector map stays out of the way here too.
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _syntheticHole(),
      );

      _expectSatelliteMeasuring();
      _expectRendered(l10n.holeNoGeometryBodyNoImagery);
    });

    for (final locale in const [Locale('en'), Locale('vi')]) {
      testWidgets('takes its wording from l10n in ${locale.languageCode}', (
        tester,
      ) async {
        final l10n = await _pump(tester, packageId: null, locale: locale);

        _expectRendered(l10n.holeNoGeometryTitle);
        _expectRendered(l10n.holeNoGeometryBodyNoImagery);
        _expectRendered(l10n.measureWithoutImagery);
      });
    }

    testWidgets('and the two languages really differ', (tester) async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final vi = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(
        en.holeNoGeometryBodyNoImagery,
        isNot(vi.holeNoGeometryBodyNoImagery),
      );
      expect(en.measureWithoutImagery, isNot(vi.measureWithoutImagery));
      expect(
        en.measureEmptyBodyNoImagery,
        isNot(vi.measureEmptyBodyNoImagery),
      );
      expect(en.basemapMeasure, isNot(vi.basemapMeasure));
      expect(en.basemapSwitchToMeasure, isNot(vi.basemapSwitchToMeasure));
      expect(en.measureYouToGreen, isNot(vi.measureYouToGreen));
    });
  });

  group('a hole whose geometry was synthesised, not surveyed', () {
    testWidgets('opens the measuring tool over imagery, not the vector map', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _syntheticHole(),
        imageryConfig: _imageryAvailable,
      );

      _expectSatelliteMeasuring();
      _expectRendered(l10n.holeNoGeometryBadge);
      // Imagery is real here, so the imagery wording is the honest one.
      _expectRendered(l10n.holeNoGeometryBody);
    });

    testWidgets('offers the measuring tool by name when there is no imagery', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _syntheticHole(),
      );

      // The second basemap option is the measuring tool, not a photograph, so
      // it is labelled for what it is and stays reachable. It used to be
      // disabled here, which on a database where every hole is unverified
      // locked the golfer out of their only distance tool.
      _expectRendered(l10n.basemapMeasure);
      expect(find.text(l10n.basemapSatellite, skipOffstage: false), findsNothing);
      // It announces itself as the measuring tool, not as unavailable imagery.
      // Matched as a substring: the option's own Text merges into the node.
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(l10n.basemapSwitchToMeasure)),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(l10n.basemapSatelliteUnavailableTitle)),
        ),
        findsNothing,
      );

      semantics.dispose();
    });

    testWidgets('lets the golfer switch to the vector map and back', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _syntheticHole(),
      );

      await tester.tap(find.text(l10n.basemapCourseMap, skipOffstage: false));
      await tester.pump();
      expect(
        find.byType(SatelliteMeasureView, skipOffstage: false),
        findsNothing,
      );

      await tester.tap(find.text(l10n.basemapMeasure, skipOffstage: false));
      await tester.pump();
      _expectSatelliteMeasuring();
    });

    testWidgets('never calls the derived green position surveyed', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        packageId: 'package-1',
        holeMap: _syntheticHole(),
        imageryConfig: _imageryAvailable,
      );

      // The green centroid comes from the same invented coordinates as the
      // hole. Quoting it with a surveyed green's 2 m error bar would be a
      // claim the data does not support.
      _expectRendered(l10n.measureGreenEstimated);
      expect(
        find.text(l10n.measureGreenSurveyed, skipOffstage: false),
        findsNothing,
      );
    });
  });

  group('a hole that was surveyed', () {
    testWidgets('opens as the vector strategic map once chosen', (tester) async {
      // The map now opens on satellite by default — the photograph is the
      // actual course, and on most holes the vector layer is a derived
      // rectangle. Asking for the strategic map is the deliberate second look.
      BasemapPreference.choose(BasemapMode.courseMap);
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
