// Widget tests for the Target tab of an active round.
//
// The bug these were written for: HoleMapBloc used to be created inside
// HoleMapScreen, below the tab stack, so the target a golfer dropped on the
// Map tab did not exist as far as the Target tab standing next to it was
// concerned. The tab could only print a leaflet telling the golfer to look at
// the other tab. Every test below reads the bloc from the Target tab's own
// context — if the bloc ever moves back under HoleMapScreen these stop
// compiling their way to a pass and start throwing ProviderNotFoundException.
//
// The second thing under test is honesty. A distance is only shown when the
// positions it rests on are real: no GPS fix means no golfer→target figure at
// all rather than one measured from (0, 0), and a hole with no known green
// means no target→green figure. Every figure that is shown carries the ±
// tolerance it earned, exactly as the measuring tool presents it.

import 'dart:async';

import 'package:course_package/course_package.dart' hide AccuracyClass;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
// course_package exports its own AccuracyClass; this file needs the domain one.
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_bloc.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_event.dart';
import 'package:vsp_mobile/features/round/presentation/active_round_screen.dart';
import 'package:vsp_mobile/features/round/presentation/active_round_target_view.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

// ─── Geometry under test ────────────────────────────────────────────────────
//
// One degree of latitude is 6 371 000 × π/180 = 111 194.9 m on the sphere the
// app measures with, so the numbers below are exact to the metre and are
// asserted as literals. Anything that changes the unit, the rounding or the
// leg that is being rendered breaks them.

/// Where the golfer is standing.
const _golferLat = 10.7000;

/// 0.0010° north of the golfer — 111.19 m, displayed as "111 m".
const _targetLat = 10.7010;

/// 0.0030° north of the golfer, 0.0020° beyond the target — 222.39 m on to
/// the green, displayed as "222 m".
const _pinLat = 10.7030;

/// 0.0005° south of the start. From here the target is 0.0015° away —
/// 166.79 m, displayed as "167 m".
const _golferLatAfterWalking = 10.6995;

const _lng = 106.7000;

/// A green drawn as a polygon: near edge 0.0040° north of the golfer
/// (444.78 m → "445 m"), far edge 0.0050° (555.97 m → "556 m"), mean of the
/// outline 0.0045° (500.38 m → "500 m"). Deliberately clear of every other
/// figure in this file so a green number can never be mistaken for a target
/// one.
const _greenNearLat = 10.7040;
const _greenFarLat = 10.7050;

const _holeNumber = 7;

// ─── Fakes ──────────────────────────────────────────────────────────────────

/// A GPS source the test drives by hand.
class _FakeLocationService implements LocationService {
  final _controller = StreamController<QualifiedLocation>.broadcast();

  QualifiedLocation? _last;

  _FakeLocationService({QualifiedLocation? initial}) : _last = initial;

  /// Delivers a fix as the device would.
  void emitFix(QualifiedLocation fix) {
    _last = fix;
    _controller.add(fix);
  }

  @override
  Stream<QualifiedLocation> get locationStream => _controller.stream;

  @override
  QualifiedLocation? get lastLocation => _last;

  @override
  Future<QualifiedLocation> getCurrentLocation() async =>
      _last ?? QualifiedLocation.unavailable();

  @override
  void start() {}

  @override
  void stop() {}

  @override
  Future<bool> isLocationAvailable() async => _last != null;

  @override
  Duration get stationaryInterval => const Duration(seconds: 30);

  @override
  Duration get activeInterval => const Duration(seconds: 5);

  @override
  void dispose() => _controller.close();
}

/// Serves one hole, so the Target tab has something to be ready about.
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

QualifiedLocation _fix(
  double latitude, {
  double? accuracyMeters = 4,
  bool isStale = false,
}) => QualifiedLocation(
  latitude: latitude,
  longitude: _lng,
  accuracyMeters: accuracyMeters,
  timestamp: DateTime.now(),
  source: LocationSource.gps,
  isStale: isStale,
);

/// A surveyed hole. The pin is official and current, so the green position is
/// the one thing here we are allowed to call surveyed.
/// A hole somebody digitised and somebody else checked. Without this the
/// coordinates are unverified, and an unverified hole is deliberately not
/// allowed to claim a surveyed green — see hole_geometry_coverage.dart.
const HoleDataProvenance _surveyed = HoleDataProvenance(
  accuracyClass: AccuracyClass.classC,
  verificationStatus: VerificationStatus.verified,
);

HoleMapEntity _hole({bool withPin = true}) => HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: _holeNumber,
  par: 4,
  provenance: _surveyed,
  pin: withPin
      ? PinEntity(
          holeId: '$_holeNumber',
          holeNumber: _holeNumber,
          latitude: _pinLat,
          longitude: _lng,
          source: PinSource.official,
          effectiveDate: DateTime(2026),
        )
      : null,
  layers: const {
    MapLayerType.fairway: MapLayerEntity(
      type: MapLayerType.fairway,
      format: LayerGeometryFormat.geoJson,
      style: LayerStyle(),
      geoJson: {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [_lng, _golferLat],
        },
      },
    ),
  },
);

/// A hole whose package draws the green as a shape rather than a point. No
/// pin: the green polygon is the only geometry, which is the case the front /
/// centre / back readout exists for.
HoleMapEntity _holeWithGreenPolygon() => const HoleMapEntity(
  courseId: 'course-1',
  courseName: 'Test course',
  holeNumber: _holeNumber,
  par: 4,
  provenance: _surveyed,
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
              [_lng, _greenNearLat],
              [_lng, _greenNearLat],
              [_lng, _greenFarLat],
              [_lng, _greenFarLat],
            ],
          ],
        },
      },
    ),
  },
);

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required _FakeLocationService locationService,
  HoleMapEntity? holeMap,
  bool unsurveyed = false,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ActiveRoundScreen(
        roundId: 'round-1',
        packageId: 'package-1',
        courseId: 'course-1',
        courseName: 'Test course',
        holeNumber: _holeNumber,
        par: 4,
        yardage: 385,
        locationService: locationService,
        holeIds: const ['7'],
        playerIds: const ['me'],
        playerNames: const {'me': 'Nghi'},
        holePars: const {'7': 4},
        initialTab: ActiveRoundTab.target,
        holeMapRepository: _StubHoleMapRepository(
          unsurveyed ? null : (holeMap ?? _hole()),
        ),
        imageryConfig: SatelliteImageryConfig.unavailable,
      ),
    ),
  );
  // Once for the first frame, once for the package lookup the bloc starts.
  await tester.pump();
  await tester.pump();
  return AppLocalizations.delegate.load(locale);
}

/// The round's hole map bloc, read from the Target tab's own context.
///
/// This is the assertion the whole feature turns on: a sibling tab can reach
/// the bloc that owns the target.
HoleMapBloc _blocSeenByTargetTab(WidgetTester tester) =>
    tester.element(find.byType(ActiveRoundTargetView)).read<HoleMapBloc>();

/// Drops a target where a tap on the hole map would.
Future<void> _placeTarget(
  WidgetTester tester, {
  double latitude = _targetLat,
}) async {
  _blocSeenByTargetTab(tester).add(
    UpdateTarget(latitude: latitude, longitude: _lng),
  );
  // Bloc events are delivered on a microtask, so the emit lands on the frame
  // after the one that dispatched it.
  await tester.pump();
  await tester.pump();
}

void _expectRendered(String text) {
  expect(find.text(text, skipOffstage: false), findsWidgets, reason: text);
}

void _expectAbsent(String text) {
  expect(find.text(text, skipOffstage: false), findsNothing, reason: text);
}

void main() {
  group('the Target tab and the target on the map', () {
    testWidgets('sees the target the golfer placed, and both distances', (
      tester,
    ) async {
      final gps = _FakeLocationService(initial: _fix(_golferLat));
      final l10n = await _pump(tester, locationService: gps);

      // Nothing placed yet: the tab asks for a target rather than inventing one.
      _expectRendered(l10n.activeRoundTargetMessage);
      expect(
        find.byKey(activeRoundTargetReadoutKey, skipOffstage: false),
        findsNothing,
      );

      await _placeTarget(tester);

      expect(
        find.byKey(activeRoundTargetReadoutKey, skipOffstage: false),
        findsOneWidget,
      );
      // Golfer → target, 0.0010° of latitude.
      _expectRendered(l10n.measureFromYou);
      _expectRendered('111 m');
      // Target → green, a further 0.0020°.
      _expectRendered(l10n.measureToGreen);
      _expectRendered('222 m');
      // Neither number is quoted without the error bar it earned:
      // √(4² + 5²) = 6.4 from the golfer, √(5² + 2²) = 5.4 on to a surveyed
      // green — both rounded up, never down.
      _expectRendered('±7 m');
      _expectRendered('±6 m');
      _expectRendered(l10n.measureGreenSurveyed);
    });

    testWidgets('follows the golfer as they walk', (tester) async {
      final gps = _FakeLocationService(initial: _fix(_golferLat));
      final l10n = await _pump(tester, locationService: gps);
      await _placeTarget(tester);
      _expectRendered('111 m');

      gps.emitFix(_fix(_golferLatAfterWalking));
      await tester.pump();
      await tester.pump();

      // 0.0015° from the new position.
      _expectRendered('167 m');
      _expectAbsent('111 m');
      // The target has not moved, so what is left to the green has not either.
      _expectRendered('222 m');
      _expectRendered(l10n.measureFromYou);
    });

    testWidgets('follows the target as the golfer moves it', (tester) async {
      await _pump(
        tester,
        locationService: _FakeLocationService(initial: _fix(_golferLat)),
      );
      await _placeTarget(tester);
      _expectRendered('111 m');

      // Dragged back to 0.0005° out: 55.60 m from the golfer, 278.0 m left on
      // to the green. Both legs move, and neither old figure survives.
      await _placeTarget(tester, latitude: 10.7005);

      _expectRendered('56 m');
      _expectRendered('278 m');
      _expectAbsent('111 m');
      _expectAbsent('222 m');
    });
  });

  group('honest degradation', () {
    testWidgets('no GPS fix means no distance from the golfer', (tester) async {
      final gps = _FakeLocationService();
      final l10n = await _pump(tester, locationService: gps);

      await _placeTarget(tester);

      // Said plainly, and the golfer→target figure is simply not there. A
      // distance measured from a guessed position reads as club selection.
      _expectRendered(l10n.measureNoFix);
      _expectAbsent(l10n.measureFromYou);
      _expectAbsent('111 m');
      // What does not depend on the fix still works: the target is real and so
      // is the surveyed green between them.
      _expectRendered(l10n.measureToGreen);
      _expectRendered('222 m');
    });

    testWidgets('an unavailable fix is not treated as a position', (
      tester,
    ) async {
      // LocationService reports "unavailable" as 0,0 — the Gulf of Guinea.
      // Measuring from it would quote a confident 1 200 km.
      final gps = _FakeLocationService(initial: QualifiedLocation.unavailable());
      final l10n = await _pump(tester, locationService: gps);

      await _placeTarget(tester);

      _expectRendered(l10n.measureNoFix);
      _expectAbsent(l10n.measureFromYou);
    });

    testWidgets('a hole with no known green quotes no distance to it', (
      tester,
    ) async {
      final gps = _FakeLocationService(initial: _fix(_golferLat));
      final l10n = await _pump(
        tester,
        locationService: gps,
        holeMap: _hole(withPin: false),
      );

      await _placeTarget(tester);

      _expectRendered(l10n.measureGreenUnknown);
      _expectAbsent(l10n.measureToGreen);
      _expectAbsent('222 m');
      // The half we do know is still answered.
      _expectRendered(l10n.measureFromYou);
      _expectRendered('111 m');
    });

    testWidgets('a weak fix is flagged, not quietly rounded away', (
      tester,
    ) async {
      final gps = _FakeLocationService(
        initial: _fix(_golferLat, accuracyMeters: 30, isStale: true),
      );
      final l10n = await _pump(tester, locationService: gps);

      await _placeTarget(tester);

      _expectRendered(l10n.measureWeakFix);
      _expectRendered(l10n.measureStaleFix);
      _expectRendered('111 m');
      // √(30² + 5²) = 30.4 — the distance is real, its precision is not.
      _expectRendered('±31 m');
    });

    testWidgets('an unsurveyed hole says so instead of showing a readout', (
      tester,
    ) async {
      final gps = _FakeLocationService(initial: _fix(_golferLat));
      final l10n = await _pump(
        tester,
        locationService: gps,
        unsurveyed: true,
      );

      // There is no hole geometry to drop a target on, so the tab points at
      // the one thing that does work there — measuring on satellite imagery.
      _expectRendered(l10n.activeRoundTargetUnsurveyedHeading);
      _expectRendered(l10n.activeRoundTargetUnsurveyedMessage);
      expect(
        find.byKey(activeRoundTargetReadoutKey, skipOffstage: false),
        findsNothing,
      );
    });
  });

  // The three numbers a golfer looks at before every approach. They used to
  // live on an orphaned screen wired to a geometry model nothing populated, so
  // in production it would have said "No hole data" on every hole. They are
  // computed here from the green polygon the round already loads, and they
  // need no target — which is the point: they are useful from the tee.
  group('front, centre and back of the green', () {
    testWidgets('are shown from the green the package draws, with no target', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        locationService: _FakeLocationService(initial: _fix(_golferLat)),
        holeMap: _holeWithGreenPolygon(),
      );

      expect(
        find.byKey(activeRoundGreenReadoutKey, skipOffstage: false),
        findsOneWidget,
      );
      _expectRendered(l10n.activeRoundGreenFront);
      _expectRendered('445 m');
      _expectRendered(l10n.activeRoundGreenCentre);
      _expectRendered('500 m');
      _expectRendered(l10n.activeRoundGreenBack);
      _expectRendered('556 m');
      // √(4² + 5²) = 6.4, rounded up — the same error bar the measuring tool
      // would quote for the same two positions.
      _expectRendered('±7 m');
      // No target has been placed, and the tab still asks for one.
      _expectRendered(l10n.activeRoundTargetMessage);
    });

    testWidgets('follow the golfer as they walk', (tester) async {
      final gps = _FakeLocationService(initial: _fix(_golferLat));
      await _pump(
        tester,
        locationService: gps,
        holeMap: _holeWithGreenPolygon(),
      );
      _expectRendered('445 m');

      // 0.0005° closer: 55.60 m off every leg. Front 389 m, centre 445 m,
      // back 500 m — the whole set walks in with the golfer.
      gps.emitFix(_fix(10.7005));
      await tester.pump();
      await tester.pump();

      _expectRendered('389 m');
      _expectRendered('445 m');
      _expectRendered('500 m');
      // The figure the far edge used to read is gone rather than lingering.
      _expectAbsent('556 m');
    });

    testWidgets('are absent without a fix — all three rest on one', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        locationService: _FakeLocationService(),
        holeMap: _holeWithGreenPolygon(),
      );

      expect(
        find.byKey(activeRoundGreenReadoutKey, skipOffstage: false),
        findsNothing,
      );
      _expectAbsent(l10n.activeRoundGreenFront);
      _expectAbsent('445 m');
    });

    testWidgets('are absent on a hole whose green is only a point', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        locationService: _FakeLocationService(initial: _fix(_golferLat)),
        // The default fixture's green is a pin, not an outline.
        holeMap: _hole(),
      );

      expect(
        find.byKey(activeRoundGreenReadoutKey, skipOffstage: false),
        findsNothing,
      );
      _expectAbsent(l10n.activeRoundGreenFront);
    });

    testWidgets('take their labels from l10n in both languages', (
      tester,
    ) async {
      for (final locale in const [Locale('en'), Locale('vi')]) {
        final l10n = await _pump(
          tester,
          locationService: _FakeLocationService(initial: _fix(_golferLat)),
          holeMap: _holeWithGreenPolygon(),
          locale: locale,
        );

        _expectRendered(l10n.activeRoundGreenHeading);
        _expectRendered(l10n.activeRoundGreenFront);
        _expectRendered(l10n.activeRoundGreenCentre);
        _expectRendered(l10n.activeRoundGreenBack);
        _expectRendered(l10n.activeRoundGreenMeasuredNote);
      }

      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final vi = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(en.activeRoundGreenHeading, isNot(vi.activeRoundGreenHeading));
      expect(en.activeRoundGreenFront, isNot(vi.activeRoundGreenFront));
      expect(en.activeRoundGreenCentre, isNot(vi.activeRoundGreenCentre));
      expect(en.activeRoundGreenBack, isNot(vi.activeRoundGreenBack));
      expect(
        en.activeRoundGreenMeasuredNote,
        isNot(vi.activeRoundGreenMeasuredNote),
      );
    });
  });

  group('language', () {
    for (final locale in const [Locale('en'), Locale('vi')]) {
      testWidgets('the readout labels come from l10n in ${locale.languageCode}',
          (tester) async {
        final gps = _FakeLocationService(initial: _fix(_golferLat));
        final l10n = await _pump(
          tester,
          locationService: gps,
          locale: locale,
        );

        await _placeTarget(tester);

        _expectRendered(l10n.measureFromYou);
        _expectRendered(l10n.measureToGreen);
        _expectRendered(l10n.activeRoundTargetMeasuredNote);
      });
    }

    testWidgets('and the two languages really differ', (tester) async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final vi = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(en.measureFromYou, isNot(vi.measureFromYou));
      expect(en.measureToGreen, isNot(vi.measureToGreen));
      expect(
        en.activeRoundTargetMeasuredNote,
        isNot(vi.activeRoundTargetMeasuredNote),
      );
    });
  });
}
