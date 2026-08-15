// The ghost banner.
//
// The race is hole-for-hole over what both cards have, so it is live from the
// second hole and silent before that. It is also silent for a golfer with no
// completed round here, and offline — a scorecard is not worth interrupting
// for an opponent who is optional.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/ghost/ghost_round.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _FakeApi extends GhostApi {
  _FakeApi({this.ghost, this.fail = false});

  final GhostRound? ghost;
  final bool fail;

  @override
  Future<GhostRound?> forCourse({
    required int courseId,
    int? backNineCourseId,
  }) async {
    if (fail) throw Exception('offline');
    return ghost;
  }
}

GhostRound ghostOf(Map<int, int> holes) => GhostRound(
      playedOn: DateTime(2026, 3, 1),
      totalStrokes: holes.values.fold(0, (a, b) => a + b),
      strokesByHole: holes,
    );

Widget host(GhostApi api, Map<int, int> mine) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(
        body: GhostBanner(courseId: 1, grossByHole: mine, api: api),
      ),
    );

void main() {
  testWidgets('races only the holes both cards have', (tester) async {
    // Ghost played 4,4,4; the golfer is through two holes in 4 and 3.
    await tester.pumpWidget(host(
      _FakeApi(ghost: ghostOf({1: 4, 2: 4, 3: 4})),
      {1: 4, 2: 3},
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('hơn vòng hay nhất 1 gậy sau 2 hố'),
        findsOneWidget);
  });

  testWidgets('says who is ahead when the ghost is', (tester) async {
    await tester.pumpWidget(host(
      _FakeApi(ghost: ghostOf({1: 4, 2: 4})),
      {1: 6, 2: 4},
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('hay nhất đang hơn bạn 2 gậy'), findsOneWidget);
  });

  testWidgets('a golfer with no completed round here sees nothing',
      (tester) async {
    await tester.pumpWidget(host(_FakeApi(ghost: null), {1: 4}));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ghost_banner')), findsNothing);
  });

  testWidgets('nothing scored yet is nothing to race', (tester) async {
    await tester.pumpWidget(host(
      _FakeApi(ghost: ghostOf({1: 4, 2: 4})),
      const {},
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ghost_banner')), findsNothing);
  });

  testWidgets('offline collapses quietly', (tester) async {
    await tester.pumpWidget(host(_FakeApi(fail: true), {1: 4}));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ghost_banner')), findsNothing);
  });
}
