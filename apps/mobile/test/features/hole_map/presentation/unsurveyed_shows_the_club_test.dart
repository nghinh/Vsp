// A hole nobody has traced still opens over the golf course.
//
// Reported from the course with a screenshot of the 12th: the header read
// "Long Biên Golf Course", the card said "Hố này chưa có bản đồ khảo sát", and
// the photograph underneath was a street of rooftops — "Sao vẫn không hiện vị
// trí sân".
//
// Nothing was wrong with the imagery. `HoleMapUnsurveyed` carried a course
// name and a hole number and no position at all, and `UnsurveyedHoleView`
// passed no centre to the measuring map, so that map fell through to the only
// coordinate it had: the golfer's fix. The golfer was not at the club.
//
// The club has a published latitude and longitude — Long Biên's Championship
// course answers 21.0384099, 105.8915159 — and that is what a golfer opening
// the map is asking to see. It is the club rather than the hole because there
// is no hole to point at: that is what "chưa khảo sát" means.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart' as vsp;
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/unsurveyed_hole_view.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/satellite_measure_view.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

const _imagery = SatelliteImageryConfig(
  provider: SatelliteImageryProvider.custom,
  tileUrlTemplate: 'https://example.invalid/{z}/{y}/{x}',
  attributionText: 'Test imagery',
  requiresMapboxLogo: false,
  tileSize: 256,
  maxZoom: 19,
);

/// Long Biên's club position, as `/courses/3/search-result` answers it.
const _longBien = vsp.LatLng(latitude: 21.0384099, longitude: 105.8915159);

Future<void> _pump(WidgetTester tester, {vsp.LatLng? courseLocation}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: UnsurveyedHoleView(
          config: _imagery,
          courseLocation: courseLocation,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the photograph is aimed at the club', (tester) async {
    await _pump(tester, courseLocation: _longBien);

    final map = tester.widget<SatelliteMeasureView>(
      find.byType(SatelliteMeasureView),
    );
    expect(
      map.fallbackCenter,
      isNotNull,
      reason: 'with no centre the map falls through to the golfer, who may be '
          'anywhere — the screenshot that reported this was of rooftops',
    );
    expect(map.fallbackCenter!.latitude, closeTo(21.0384099, 1e-7));
    expect(map.fallbackCenter!.longitude, closeTo(105.8915159, 1e-7));
  });

  testWidgets('and stood far enough back to hold a club, not a hole', (
    tester,
  ) async {
    await _pump(tester, courseLocation: _longBien);

    final map = tester.widget<SatelliteMeasureView>(
      find.byType(SatelliteMeasureView),
    );
    expect(
      map.initialZoom,
      lessThan(17),
      reason: 'there is no hole to frame here, only a course to find',
    );
  });

  testWidgets('a club we cannot place still opens on the golfer', (
    tester,
  ) async {
    // Offline, or a course the server has no position for. Centring on the
    // golfer is then the best there is, and it is right whenever they are
    // actually standing on the course.
    await _pump(tester);

    final map = tester.widget<SatelliteMeasureView>(
      find.byType(SatelliteMeasureView),
    );
    expect(map.fallbackCenter, isNull);
  });

  test('the state carries it', () {
    const state = HoleMapUnsurveyed(
      courseName: 'Long Biên Golf Course',
      holeNumber: 12,
      courseLocation: _longBien,
    );

    expect(state.courseLocation, _longBien);
  });

  // Three edits away from the golfer's screen, and every one of them is a
  // silent no-op on its own: a state field nothing reads, a bloc that looks
  // the club up through an API it was never given, a view handed a position it
  // does not pass on. The widget tests above cover the last hop; these cover
  // the two that have no widget.
  group('and the lookup is actually wired', () {
    String _read(String path) => File(path).readAsStringSync();

    test('the bloc asks for the club on the unsurveyed path', () {
      final source = _read(
        'lib/features/hole_map/presentation/hole_map_bloc.dart',
      );

      expect(source, contains('courseLocation: await _courseLocation('));
      expect(
        'courseLocation: await _courseLocation('.allMatches(source).length,
        2,
        reason:
            'two paths reach HoleMapUnsurveyed — no package at all, and a '
            'package that carries nothing for this hole — and a golfer cannot '
            'tell them apart',
      );
    });

    test('and both screens give it something to ask with', () {
      // `_courseApi` is null by default, deliberately: this bloc is built in
      // tests where no network should be reached. That also means forgetting
      // it at a call site costs nothing at compile time and everything on the
      // phone.
      for (final screen in [
        'lib/features/hole_map/presentation/hole_map_screen.dart',
        'lib/features/round/presentation/active_round_screen.dart',
      ]) {
        expect(
          _read(screen),
          contains('courseApi: CourseSearchApi('),
          reason: '$screen builds a HoleMapBloc that could not look a club up',
        );
      }
    });
  });
}
