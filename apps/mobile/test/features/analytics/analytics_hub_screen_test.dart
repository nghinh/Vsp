// AnalyticsHubScreen Widget Tests — VSP Mobile App
//
// Verifies the analytics hub (the Home "More" → Analytics entry point) renders
// every MVP 2–4 analytics destination so the features are reachable.
//
// Epic 11 reachability wiring.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/analytics/presentation/analytics_hub_screen.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  group('AnalyticsHubScreen', () {
    testWidgets('renders the hub title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AnalyticsHubScreen(),
        ),
      );

      expect(find.text('Phân tích & Hiệu suất'), findsOneWidget);
    });

    testWidgets('lists every analytics destination', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AnalyticsHubScreen(),
        ),
      );

      expect(find.text('Hiệu suất gậy & Độ phân tán'), findsOneWidget);
      expect(find.text('Vùng phát bóng (Driving Zone)'), findsOneWidget);
      expect(find.text('Strokes Gained'), findsOneWidget);
      expect(find.text('Smart Target (Caddie)'), findsOneWidget);
    });

    testWidgets('renders one navigable tile per destination', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AnalyticsHubScreen(),
        ),
      );

      // Each tile ends with a chevron affordance; four destinations ⇒ four.
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
    });
  });
}
