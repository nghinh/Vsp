// A golfer who loses signal is told so in words, not in a translation key.
//
// Found by the offline sweep — the first thing that had ever opened this screen
// with no server behind it. Under the heading "Không tải được vòng đấu", where
// the explanation goes, the app printed:
//
//     msg.networkError
//
// That is an `AppMessages` key. The layers that throw have no BuildContext, so
// they carry a key and the UI resolves it with `context.tr(...)` — which every
// other screen does and this one did not. The heading was translated, which is
// what made it look finished.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/features/round/data/round_history_repository.dart';
import 'package:vsp_mobile/features/round/presentation/rounds_history_tab.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// A server that is not there.
class _NoServer extends RoundHistoryRepository {
  @override
  Future<RoundHistoryPage> fetchRounds({int page = 0, int size = 20}) async {
    throw const VspApiException(
      code: 'NETWORK',
      message: AppMessages.networkError,
    );
  }
}

void main() {
  testWidgets('the network error reads as Vietnamese', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoundsHistoryTab(repository: _NoServer()),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(
      find.text(AppMessages.networkError),
      findsNothing,
      reason: 'this is the defect: the raw key "msg.networkError" on screen',
    );
    expect(find.text(l10n.msgNetworkError), findsOneWidget);
  });

  testWidgets('and offers a way to try again', (tester) async {
    // An error screen with nothing to do on it is a dead end, and this one is
    // reached by walking out of signal — which is temporary by nature.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoundsHistoryTab(repository: _NoServer()),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(find.text(l10n.commonRetry), findsOneWidget);
  });
}
