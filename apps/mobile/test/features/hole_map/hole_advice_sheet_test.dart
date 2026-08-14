// The hole advice sheet.
//
// What is asserted here is mostly what the sheet does when the server gives it
// less than everything, because that is the ordinary case: most courses have no
// stroke index, most golfers have never played the hole in question, and a
// deployment without a model configured returns no sentence at all. Each of
// those has to leave a screen worth looking at.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_advice_api.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/hole_advice_sheet.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _FakeApi extends HoleAdviceApi {
  _FakeApi(this.advice, {this.failWith});

  final HoleAdvice advice;
  final Object? failWith;
  int calls = 0;

  @override
  Future<HoleAdvice> forHole({
    required int courseId,
    required int holeNumber,
    String? tee,
  }) async {
    calls++;
    if (failWith != null && calls == 1) {
      throw failWith!;
    }
    return advice;
  }
}

HoleAdvice card({
  int par = 4,
  int? strokeIndex = 4,
  int? yards = 415,
  String? tee = 'Black',
  int rounds = 0,
  double? average,
  int? best,
  int? fairways,
  int? gir,
  String? advice,
}) => HoleAdvice(
  par: par,
  strokeIndex: strokeIndex,
  yards: yards,
  tee: tee,
  roundsPlayed: rounds,
  averageStrokes: average,
  bestStrokes: best,
  fairwaysHit: fairways,
  greensInRegulation: gir,
  advice: advice,
);

Future<void> pumpSheet(WidgetTester tester, HoleAdviceApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: HoleAdviceSheet(courseId: 1387, holeNumber: 7, api: api),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the hole advice sheet', () {
    testWidgets('shows the hole and the golfer\'s own record on it', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        _FakeApi(
          card(rounds: 6, average: 5.4, best: 4, fairways: 1, gir: 0),
        ),
      );

      expect(find.text('4'), findsWidgets); // par
      expect(find.text('5.4'), findsOneWidget);
      expect(find.text('1/6'), findsOneWidget);
      expect(find.text('0/6'), findsOneWidget);
    });

    // The ordinary first visit. It has to say so rather than render an empty
    // band that reads as a failure to load.
    testWidgets('says so when the golfer has never played the hole', (
      tester,
    ) async {
      await pumpSheet(tester, _FakeApi(card()));

      expect(find.textContaining('chưa chơi hố này'), findsOneWidget);
      expect(find.text('5.4'), findsNothing);
    });

    // A deployment with no model configured. The two bands above it are the
    // golfer's own data and stand on their own, so the sheet is still worth
    // opening — it must not apologise for a server-side setting.
    testWidgets('draws the facts when the server sends no sentence', (
      tester,
    ) async {
      await pumpSheet(tester, _FakeApi(card(rounds: 3, average: 5.0, best: 4)));

      expect(find.text('5.0'), findsOneWidget);
      expect(find.text('CADDIE GỢI Ý'), findsNothing);
    });

    testWidgets('shows the caddie note when there is one', (tester) async {
      await pumpSheet(
        tester,
        _FakeApi(card(advice: 'Đánh sắt 7 vào giữa green, đừng ham cờ.')),
      );

      expect(find.text('CADDIE GỢI Ý'), findsOneWidget);
      expect(
        find.text('Đánh sắt 7 vào giữa green, đừng ham cờ.'),
        findsOneWidget,
      );
    });

    // Most courses in the country publish no index row.
    testWidgets('omits the stroke index where the club published none', (
      tester,
    ) async {
      await pumpSheet(tester, _FakeApi(card(strokeIndex: null)));

      expect(find.text('Chỉ số gậy'), findsNothing);
      expect(find.text('Par'), findsOneWidget);
    });

    testWidgets('offers a retry after a failure, and recovers', (tester) async {
      final api = _FakeApi(card(rounds: 2, average: 4.5), failWith: Exception('down'));
      await pumpSheet(tester, api);

      expect(find.byKey(const Key('hole_advice_retry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hole_advice_retry')));
      await tester.pumpAndSettle();

      expect(find.text('4.5'), findsOneWidget);
      expect(find.byKey(const Key('hole_advice_retry')), findsNothing);
    });
  });
}
