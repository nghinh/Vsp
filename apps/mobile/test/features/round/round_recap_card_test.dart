// The recap card.
//
// What is asserted is the card's silence: it appears only when the server
// actually wrote a sentence, and disappears — rather than erroring — for the
// unsynced round, the model-less deployment and the dead network. The summary
// screen it sits on is complete without it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/round/presentation/widgets/round_recap_card.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _FakeApi extends RoundRecapApi {
  _FakeApi({this.recap, this.fail = false});

  final String? recap;
  final bool fail;

  @override
  Future<String?> forRound(String roundId) async {
    if (fail) throw Exception('offline');
    return recap;
  }
}

Widget host(RoundRecapApi api) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(
        body: RoundRecapCard(roundId: 'r1', subject: 'Sân Kiểm Thử', api: api),
      ),
    );

void main() {
  testWidgets('shows the sentence and a share button', (tester) async {
    await tester.pumpWidget(
        host(_FakeApi(recap: 'Hôm nay 38 gậy, birdie hố 3! 🎉')));
    await tester.pumpAndSettle();

    expect(find.textContaining('birdie hố 3'), findsOneWidget);
    expect(find.byKey(const Key('round_recap_share')), findsOneWidget);
  });

  testWidgets('a deployment without a model leaves no empty card',
      (tester) async {
    await tester.pumpWidget(host(_FakeApi(recap: null)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('round_recap_card')), findsNothing);
  });

  testWidgets('an unsynced round collapses quietly', (tester) async {
    await tester.pumpWidget(host(_FakeApi(fail: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('round_recap_card')), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
}
