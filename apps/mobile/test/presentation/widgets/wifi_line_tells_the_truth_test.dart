// The Wi-Fi line says what is actually happening to the download.
//
// Found by the screen-by-screen sweep, on the download screen for Long Biên's
// Đường A: the switch "Chỉ tải qua Wi-Fi" was **off**, and underneath it, in
// destructive red, the app said "Không có Wi-Fi — tạm dừng tải".
//
// Nothing was paused. The golfer had just told the app they did not mind
// mobile data, and the app answered by telling them to go and find Wi-Fi — on
// the one screen where they were trying to download, in the colour reserved
// for things that have gone wrong.
//
// The cause was that the line was chosen from the network alone and never
// looked at the switch above it. The app's own neutral wording for this case —
// "Chưa kết nối Wi-Fi", a fact rather than a consequence — was already
// translated and unused.
//
// The rule: red, and the word "tạm dừng", belong to the one combination that
// actually stops a download.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vsp_mobile/data/services/connectivity_service.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/widgets/wifi_only_toggle.dart';

/// A connectivity service that answers whatever the test needs.
class _Fake extends ConnectivityService {
  _Fake({
    required super.prefs,
    required this.restrictionOn,
    required this.wifi,
  });

  final bool restrictionOn;
  final bool wifi;

  @override
  bool get wifiOnlyEnabled => restrictionOn;

  @override
  Future<bool> get isWifiConnected async => wifi;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

Future<void> _pump(
  WidgetTester tester, {
  required bool restrictionOn,
  required bool wifi,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WifiOnlyToggle(
          connectivityService: _Fake(
            prefs: prefs,
            restrictionOn: restrictionOn,
            wifi: wifi,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('restriction off, no Wi-Fi: states the fact, does not alarm', (
    tester,
  ) async {
    await _pump(tester, restrictionOn: false, wifi: false);
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(
      find.text(l10n.wifiNotConnected),
      findsNothing,
      reason: 'this is the defect: "tạm dừng tải" while nothing is paused',
    );
    expect(find.text(l10n.wifiStatusNotConnected), findsOneWidget);

    // And not in the colour that means something has gone wrong.
    final line = tester.widget<Text>(find.text(l10n.wifiStatusNotConnected));
    final surface = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme.onSurfaceVariant;
    expect(line.style?.color, surface);
  });

  testWidgets('restriction on, no Wi-Fi: says the download is paused', (
    tester,
  ) async {
    // The one combination that actually stops a download. This is what the red
    // is for, and it must survive the fix.
    await _pump(tester, restrictionOn: true, wifi: false);
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(find.text(l10n.wifiNotConnected), findsOneWidget);

    final line = tester.widget<Text>(find.text(l10n.wifiNotConnected));
    final surface = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme.onSurfaceVariant;
    expect(
      line.style?.color,
      isNot(surface),
      reason: 'a paused download is worth a colour',
    );
  });

  testWidgets('restriction on, Wi-Fi present: says it is connected', (
    tester,
  ) async {
    await _pump(tester, restrictionOn: true, wifi: true);
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(find.text(l10n.wifiConnected), findsOneWidget);
  });

  testWidgets('restriction off, Wi-Fi present: still just a fact', (
    tester,
  ) async {
    await _pump(tester, restrictionOn: false, wifi: true);
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(find.text(l10n.wifiStatusConnected), findsOneWidget);
  });
}
