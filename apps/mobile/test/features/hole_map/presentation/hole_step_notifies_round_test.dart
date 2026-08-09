// Tests for the map telling the round it moved.
//
// The hole header's previous/next moved the map's own bloc and nothing else.
// So a golfer who walked the map forward to the 13th and then opened the Score
// tab found it still on the 1st — two tabs of the same round disagreeing about
// which hole is being played, with the scorecard being the one that records the
// shot. Observed on a device: map header "Hố 13 · Par 4 · 325 m", scorecard
// "Hố 1 trên 18".

import 'package:course_package/course_package.dart' hide AccuracyClass;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _Repository implements HoleMapRepository {
  @override
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  }) async => HoleMapEntity(
    courseId: courseId,
    courseName: courseName,
    holeNumber: holeNumber,
    par: 4,
    yardage: 361,
    layers: const {},
    provenance: HoleDataProvenance(
      accuracyClass: AccuracyClass.classC,
      verificationStatus: VerificationStatus.verified,
    ),
  );

  @override
  Future<CourseGeometryBundle?> getGeometryBundle({
    required String packageId,
    required String courseId,
  }) async => null;

  @override
  Future<List<CoursePackageManifest>> listPackages() async => const [];

  @override
  Future<String?> findPackageIdForCourse(String courseId) async => '8/1.8.3';
}

Widget harness({
  required int holeNumber,
  required ValueChanged<int>? onHoleChanged,
}) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: RepositoryProvider<HoleMapRepository>(
    create: (_) => _Repository(),
    child: HoleMapScreen(
      packageId: '8/1.8.3',
      courseId: '8',
      courseName: 'Long Thành Golf Resort — Championship',
      holeNumber: holeNumber,
      holeNumbers: const [1, 2, 3, 4, 5],
      imageryConfig: SatelliteImageryConfig.unavailable,
      onHoleChanged: onHoleChanged,
    ),
  ),
);

void main() {
  testWidgets('stepping to the next hole tells the round', (tester) async {
    final moves = <int>[];
    await tester.pumpWidget(
      harness(holeNumber: 1, onHoleChanged: moves.add),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    // Without this the map moves and the scorecard does not, and the golfer
    // records a shot against the wrong hole.
    expect(moves, [2]);
  });

  testWidgets('stepping back tells the round too', (tester) async {
    final moves = <int>[];
    await tester.pumpWidget(
      harness(holeNumber: 3, onHoleChanged: moves.add),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(moves, [2]);
  });

  testWidgets('a screen with nobody to tell still navigates', (tester) async {
    await tester.pumpWidget(harness(holeNumber: 1, onHoleChanged: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Opened on its own — from a course detail page, say — the map has no
    // round behind it, and the header must still work.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
