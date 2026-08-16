// The performance dashboard.
//
// What matters most here is the difference between zero and unknown. Nobody
// records putts on a casual round, and a tile reading "0.0 putts per hole"
// is a claim about a golfer's putting rather than an admission that nothing
// was written down. Dashes, and a word saying why.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/performance/data/performance_api.dart';
import 'package:vsp_mobile/features/performance/presentation/performance_dashboard.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _FakeApi extends PerformanceApi {
  _FakeApi(this.byWindow, {this.fail = false});

  final Map<PerformanceWindow, Performance> byWindow;
  final bool fail;
  PerformanceWindow? lastAsked;

  @override
  Future<Performance> forWindow(PerformanceWindow window) async {
    if (fail) throw Exception('offline');
    lastAsked = window;
    return byWindow[window] ?? byWindow.values.first;
  }
}

Performance played({
  int rounds = 4,
  int? bestToPar = 3,
  int? bestHoles = 9,
  double? putts = 2.0,
  double? gir = 33,
  double? fairway = 56,
}) =>
    Performance(
      rounds: rounds,
      holes: rounds * 9,
      handicap: 28,
      bestToPar: bestToPar,
      bestToParHoles: bestHoles,
      puttsPerHole: putts,
      holesWithPutts: putts == null ? 0 : rounds * 9,
      girPercent: gir,
      holesWithGir: gir == null ? 0 : rounds * 9,
      fairwayPercent: fairway,
      holesWithFairway: fairway == null ? 0 : rounds * 9,
      penaltiesPerRound: 1.0,
      distribution: const [
        ScoreBucket(label: 'BIRDIE', holes: 1, percent: 3),
        ScoreBucket(label: 'PAR', holes: 20, percent: 56),
        ScoreBucket(label: 'BOGEY', holes: 15, percent: 41),
      ],
      byPar: const [
        ParAverage(par: 3, holes: 8, average: 3.5, best: 3, worst: 5),
        ParAverage(par: 4, holes: 20, average: 5.1, best: 4, worst: 8),
      ],
    );

Widget host(PerformanceApi api) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PerformanceDashboard(api: api),
        ),
      ),
    );

void main() {
  testWidgets('shows the numbers a golfer quotes', (tester) async {
    await tester.pumpWidget(host(_FakeApi({PerformanceWindow.allTime: played()})));
    await tester.pumpAndSettle();

    expect(find.text('4'), findsWidgets);        // rounds
    expect(find.text('+3'), findsOneWidget);     // best round to par
    expect(find.text('2.0'), findsOneWidget);    // putts per hole
    expect(find.text('33%'), findsOneWidget);    // greens in regulation
  });

  testWidgets('a round with nothing recorded shows dashes, not zeroes',
      (tester) async {
    await tester.pumpWidget(host(_FakeApi({
      PerformanceWindow.allTime:
          played(putts: null, gir: null, fairway: null),
    })));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNWidgets(3));
    expect(find.textContaining('chưa ghi nhận'), findsWidgets);
    expect(find.text('0%'), findsNothing);
    expect(find.text('0.0'), findsNothing);
  });

  testWidgets('switching the window asks the server again', (tester) async {
    final api = _FakeApi({
      PerformanceWindow.allTime: played(rounds: 12),
      PerformanceWindow.last5: played(rounds: 5),
    });
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5 vòng gần nhất'));
    await tester.pumpAndSettle();

    expect(api.lastAsked, PerformanceWindow.last5);
  });

  testWidgets('a golfer with no rounds is told so, not shown zeroes',
      (tester) async {
    await tester.pumpWidget(host(_FakeApi({
      PerformanceWindow.allTime: const Performance(rounds: 0, holes: 0),
    })));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chưa có vòng nào'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await tester.pumpWidget(host(_FakeApi(const {}, fail: true)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không tải được'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
