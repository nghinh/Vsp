// Does it still fit when the golfer turns the text up?
//
// Nothing in this suite had ever pumped a widget at anything but the default
// text size, and twice today a Row overflowed the moment it was asked to hold
// slightly wider content: the weather panel's three provenance chips, and the
// course list's info chips. Both were reported by a golfer as "các khối che
// nhau" — blocks covering each other — which is exactly what an overflow looks
// like before it is diagnosed.
//
// Larger text is not an edge case here. It is a system setting, this app is
// used outdoors by people who set it, and every widget below is one somebody
// reads mid-round with a club in the other hand.
//
// Flutter throws on a RenderFlex overflow during layout, so these tests need
// no assertion beyond pumping: if the layout breaks, the test fails with the
// pixel count and the offending Row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/green_distance_reading.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/measure/presentation/widgets/no_geometry_banner.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/features/round/domain/round_summary.dart';
import 'package:vsp_mobile/features/round/domain/score_entry.dart';
import 'package:vsp_mobile/features/round/domain/sync_state.dart';
import 'package:vsp_mobile/features/round/presentation/active_round_target_view.dart';
import 'package:vsp_mobile/features/round/presentation/widgets/round_headline.dart';
import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';
import 'package:vsp_mobile/features/round_setup/presentation/widgets/package_status_banner.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/widgets/score/quick_score_strip.dart';

MeasureLeg leg(double metres) => MeasureLeg(
  kind: MeasureLegKind.fromGolfer,
  from: const LatLng(latitude: 21.0, longitude: 105.0),
  to: const LatLng(latitude: 21.001, longitude: 105.0),
  meters: metres,
  uncertaintyMeters: 4,
);

PlayerScoreSummary golfer(String name, int strokes) {
  final holes = [
    for (var i = 1; i <= 18; i++)
      ScoreEntry(holeNumber: i, par: 4, strokes: strokes, putts: 2),
  ];
  return PlayerScoreSummary(
    playerId: name,
    playerName: name,
    holes: holes,
    totalStrokes: strokes * 18,
    totalPar: 72,
    relativeScore: (strokes - 4) * 18,
    syncState: SyncState.synced,
  );
}

/// Every widget a golfer reads during or just after a round, with the widest
/// plausible content in it — long Vietnamese names, three-figure distances.
final _midRound = <String, Widget Function()>{
  'dải ghi điểm một chạm': () => QuickScoreStrip(
    par: 5,
    score: 8,
    onScore: (_) {},
    onOther: () {},
  ),
  'cự ly tới green': () => GreenReadout(
    reading: GreenDistanceReading(
      front: leg(128),
      centre: leg(137),
      back: leg(146),
    ),
    unit: DistanceUnit.meters,
    onToggleUnit: () {},
  ),
  'tổng kết một người': () => RoundHeadline(
    players: [golfer('Nguyễn Hồng Nghi', 5)],
    courseName: 'Long Biên Golf Course',
    date: '17/8/2026',
  ),
  'tổng kết bốn người': () => RoundHeadline(
    players: [
      golfer('Nguyễn Hồng Nghi', 5),
      golfer('Trần Quốc Khánh Duy', 4),
      golfer('Phạm Thị Minh Nguyệt', 6),
      golfer('Lê Bá Trường Giang', 7),
    ],
    courseName: 'Long Biên Golf Course',
    date: '17/8/2026',
  ),
  'chín đầu chín sau': () => NineTotals(player: golfer('Nghi', 5)),
  'banner chưa khảo sát': () => const NoGeometryBanner(),
  'banner gói dữ liệu': () => const PackageStatusBanner(
    packageAvailable: true,
    packageReadiness: PackageReadiness(
      status: PackageStatus.notDownloaded,
      missingCourseId: 1351,
      segments: [
        SegmentPackage(courseId: 1351, name: 'Đường A', isReady: false),
        SegmentPackage(courseId: 1352, name: 'Đường B', isReady: true),
      ],
    ),
    missingCourseName: 'Đường A',
  ),
};

void main() {
  // 1.0 is today. 1.3 is a common setting. 2.0 is the accessibility end of the
  // iOS slider, and a golfer who needs it needs it outdoors most of all.
  for (final scale in [1.0, 1.3, 2.0]) {
    group('at ${scale}× text', () {
      for (final entry in _midRound.entries) {
        testWidgets('${entry.key} vẫn vừa màn hình', (tester) async {
          // 360 dp wide — the small end of the phones this ships to, and the
          // width an overflow shows up at first.
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: VspTheme.dark(),
              locale: const Locale('vi'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(child: entry.value()),
                ),
              ),
            ),
          );
          await tester.pump();

          // Reaching here without an exception is the assertion: Flutter
          // throws on overflow during layout.
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
