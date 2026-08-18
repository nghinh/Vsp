// What the map says about the shapes it is drawing, and where its chrome sits.
//
// A golfer opened Long Biên's 1st. The map drew the fairway, both greenside
// bunkers and four tees, put a distance chip on each of them — and printed
// across the top of the picture:
//
//   CHƯA KHẢO SÁT  Hố này chưa có bản đồ khảo sát
//   Chúng tôi chưa số hoá hố này.
//
// Six labelled shapes and a notice saying they do not exist, from the same
// data, in the same widget. The banner covered two of the chips it was
// contradicting, and the club-plan button was printed across the banner.
//
// The cause of the first is one banner covering two different states: "there
// is nothing here" and "a model traced this and nobody has checked it". Only
// the first one's words were ever written. The cause of the second is that the
// satellite view handed its overlay a strip along the top, so a caller asking
// for the bottom-left corner got the bottom of the strip.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/basemap/presentation/widgets/basemap_toggle.dart';
import 'package:vsp_mobile/features/measure/domain/club_plan.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/club_plan_button.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/hole_map_view.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// One polygon, near enough to Long Biên's 1st to be the same picture.
Map<String, dynamic> _polygon() => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [105.892017, 21.036720],
            [105.891985, 21.036713],
            [105.891969, 21.036698],
            [105.892017, 21.036720],
          ],
        ],
      },
      'properties': <String, dynamic>{},
    },
  ],
};

MapLayerEntity _layer(MapLayerType type) => MapLayerEntity(
  type: type,
  format: LayerGeometryFormat.geoJson,
  geoJson: _polygon(),
  style: const LayerStyle(),
);

/// The hole as it arrives from the feature endpoint: real shapes, no survey.
HoleMapReady _tracedHole() => HoleMapReady(
  holeMap: HoleMapEntity(
    courseId: '1351',
    courseName: 'Long Biên Golf Course',
    holeNumber: 1,
    par: 0,
    layers: {
      MapLayerType.green: _layer(MapLayerType.green),
      MapLayerType.bunker: _layer(MapLayerType.bunker),
      MapLayerType.fairway: _layer(MapLayerType.fairway),
    },
  ),
  layerVisibility: const {'green': true, 'bunker': true, 'fairway': true},
  tracedShapesUnverified: true,
);

/// The same hole, with shapes the importer computed from two invented points.
///
/// Shapes, but nothing read off a photograph — so the traced wording would be
/// its own lie here, and this state keeps the "we have not digitised this"
/// banner it has always had.
HoleMapReady _syntheticHole() => HoleMapReady(
  holeMap: _tracedHole().holeMap,
  layerVisibility: const {'green': true},
  tracedShapesUnverified: false,
);

Future<AppLocalizations> _pump(WidgetTester tester, HoleMapReady state) async {
  tester.view.physicalSize = const Size(1440, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HoleMapView(
          state: state,
          imageryConfig: SatelliteImageryConfig.unavailable,
          clubs: const [
            PlannedClub(label: 'Driver', carryMeters: 210),
            PlannedClub(label: '7i', carryMeters: 140),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return AppLocalizations.delegate.load(const Locale('vi'));
}

void main() {
  setUp(BasemapPreference.resetForTesting);
  tearDown(BasemapPreference.resetForTesting);

  group('a hole drawn from shapes a model traced', () {
    testWidgets('is not told it has no map', (tester) async {
      await _pump(tester, _tracedHole());

      // The sentence the golfer read while looking at eight labelled bunkers.
      expect(
        find.byType(NoGeometryBanner, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('says who drew them instead', (tester) async {
      final l10n = await _pump(tester, _tracedHole());

      expect(
        find.text(l10n.mapTracedShapes, skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('a hole whose shapes were computed, not traced', () {
    testWidgets('keeps the banner, because nothing read the ground', (
      tester,
    ) async {
      await _pump(tester, _syntheticHole());

      expect(
        find.byType(NoGeometryBanner, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('and does not claim a model traced it', (tester) async {
      final l10n = await _pump(tester, _syntheticHole());

      expect(find.text(l10n.mapTracedShapes, skipOffstage: false), findsNothing);
    });
  });

  group('the chrome over the picture', () {
    testWidgets('puts the club-plan button in the bottom half, not on the '
        'notice', (tester) async {
      await _pump(tester, _tracedHole());

      final button = tester.getRect(find.byType(ClubPlanButton));
      final notice = tester.getRect(
        find.text(
          (await AppLocalizations.delegate.load(const Locale('vi')))
              .mapTracedShapes,
          skipOffstage: false,
        ),
      );

      // It used to be inside a top strip as tall as the banner, so
      // `Alignment.bottomLeft` resolved to the bottom of the banner and the
      // button printed over it.
      expect(button.top, greaterThan(notice.bottom));
    });

    testWidgets('and no two pieces of chrome overlap', (tester) async {
      // The notice was missing from this list. That is the whole reason a
      // test named "no two pieces of chrome overlap" ran green for weeks
      // while the map/measure switch printed straight across the sentence —
      // "…tellite imagery" and "human" behind two opaque buttons, found by
      // the first photograph ever taken of this screen and not by this test.
      //
      // Named, so a failure says which two.
      final l10n = await _pump(tester, _tracedHole());

      final chrome = <String, Rect>{
        'club plan': tester.getRect(find.byType(ClubPlanButton)),
        'basemap toggle': tester.getRect(find.byType(BasemapToggle).first),
        'traced-shapes notice': tester.getRect(
          find.text(l10n.mapTracedShapes, skipOffstage: false),
        ),
      };

      final names = chrome.keys.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          expect(
            chrome[names[i]]!.overlaps(chrome[names[j]]!),
            isFalse,
            reason: '${names[i]} overlaps ${names[j]}',
          );
        }
      }
    });

    testWidgets('and the map/measure switch still says what it is', (
      tester,
    ) async {
      // The first repair for the overlap put the notice and the switch on one
      // line, sharing the width, and the switch lost: at ordinary text size it
      // read "Cour… Meas…" — a control whose two states could no longer be
      // told apart, to make room for prose that could simply have wrapped.
      //
      // It carries icons now, in the same corner the drawn map keeps it in,
      // which retires the width contest entirely. What it must not lose is the
      // meaning: a screen reader still hears which state each half selects.
      await _pump(tester, _tracedHole());
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(
        find.bySemanticsLabel(l10n.basemapSwitchToCourseMap),
        findsWidgets,
      );
      expect(find.bySemanticsLabel(l10n.basemapSwitchToMeasure), findsWidgets);
    });

    testWidgets('and still do not at twice the text size', (tester) async {
      // Vietnamese is longer than English here, and a golfer who has turned
      // the system text up is the one most likely to need the caveat read to
      // them. Both are the same failure: a sentence that grows sideways into
      // a control that was placed against the opposite edge.
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: HoleMapView(
                state: _tracedHole(),
                imageryConfig: SatelliteImageryConfig.unavailable,
                clubs: const [PlannedClub(label: 'Driver', carryMeters: 210)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(find.text(l10n.mapTracedShapes, skipOffstage: false))
            .overlaps(tester.getRect(find.byType(BasemapToggle).first)),
        isFalse,
      );
    });
  });
}
