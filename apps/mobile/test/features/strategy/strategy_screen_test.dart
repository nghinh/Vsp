// The strategy page.
//
// Eighteen rows a golfer reads in the cart. What is asserted is the ordinary
// degradation: a golfer with no handicap gets the page without allocation and
// is told how to earn one; a hole with no stroke index simply shows no chip;
// a failed load offers a retry rather than a blank.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_advice_api.dart'
    show ClubForShot;
import 'package:vsp_mobile/features/strategy/data/strategy_api.dart';
import 'package:vsp_mobile/features/strategy/presentation/strategy_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _FakeApi extends StrategyApi {
  _FakeApi(this.strategy, {this.failFirst = false});

  final CourseStrategy strategy;
  final bool failFirst;
  int calls = 0;

  @override
  Future<CourseStrategy> forCourse({
    required int courseId,
    int? backNineCourseId,
    String? tee,
  }) async {
    calls++;
    if (failFirst && calls == 1) {
      throw Exception('down');
    }
    return strategy;
  }
}

CourseStrategy page({
  double? handicap = 20.0,
  int? strokesTotal = 20,
  int? netParTotal = 92,
  String? backNine,
  List<StrategyHole>? holes,
}) => CourseStrategy(
  courseName: 'Sân Kiểm Thử',
  backNineCourseName: backNine,
  handicapUsed: handicap,
  strokesReceivedTotal: strokesTotal,
  netParTotal: netParTotal,
  holes: holes ??
      [
        StrategyHole(
          displayHole: 1,
          par: 4,
          strokeIndex: 7,
          yards: 415,
          strokesReceived: 1,
          netPar: 5,
          roundsPlayed: 3,
          averageStrokes: 5.3,
          bestStrokes: 4,
          clubs: const [
            ClubForShot(
                shot: 1, label: 'Cú phát bóng', remainingMeters: 380,
                club: 'Driver', carryMeters: 210),
            ClubForShot(
                shot: 2, label: 'Cú vào green', remainingMeters: 170,
                club: 'Sắt 5', carryMeters: 175),
          ],
        ),
        const StrategyHole(
          displayHole: 2,
          par: 3,
          roundsPlayed: 0,
        ),
      ],
);

Widget host(StrategyApi api) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: StrategyScreen(courseId: 1, api: api),
    );

void main() {
  testWidgets('draws a row per hole with the club plan and net par',
      (tester) async {
    await tester.pumpWidget(host(_FakeApi(page())));
    await tester.pumpAndSettle();

    expect(find.text('Sân Kiểm Thử'), findsOneWidget);
    expect(find.textContaining('Par 4 · SI 7'), findsOneWidget);
    expect(find.text('Driver → Sắt 5'), findsOneWidget);
    expect(find.text('+1 → 5'), findsOneWidget);
    // Hole 2 has no index and no allocation: a plain row, no chip.
    expect(find.textContaining('Par 3'), findsOneWidget);
  });

  testWidgets('a golfer without a handicap is told how to earn one',
      (tester) async {
    await tester.pumpWidget(host(_FakeApi(
        page(handicap: null, strokesTotal: null, netParTotal: null))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chưa có handicap'), findsOneWidget);
    expect(find.textContaining('gậy chấp'), findsNothing);
  });

  testWidgets('two nines are named together', (tester) async {
    await tester.pumpWidget(host(_FakeApi(page(backNine: 'Đường Về'))));
    await tester.pumpAndSettle();

    expect(find.text('Sân Kiểm Thử + Đường Về'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry, and the retry loads',
      (tester) async {
    final api = _FakeApi(page(), failFirst: true);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không tải được'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Sân Kiểm Thử'), findsOneWidget);
    expect(api.calls, 2);
  });
}
