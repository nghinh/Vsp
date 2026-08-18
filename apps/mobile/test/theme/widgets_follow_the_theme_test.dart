// Screens take their colours from the theme, not from the dark palette.
//
// For most of this app's life `app.dart` built its own ColorScheme.dark from
// hex literals and never touched packages/mobile-theme, and 143 widgets in
// lib/features named `VspColorDark.textPrimary` and friends directly. Both
// facts were invisible: the app is dark, the dark tokens are dark, everything
// looked right. What it meant was that the palette file was not the app's
// palette — a contrast pass over it, with seven passing tests, changed nothing
// a golfer could see, and a light mode was impossible in principle rather than
// merely unfinished.
//
// These pin the mechanism that makes it fixable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/freshness_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  group('both themes carry the text tiers', () {
    test('and they are on the ThemeData, not just declared somewhere', () {
      // The failure this catches is the extension existing and never being
      // registered — every widget then silently falls back to dark.
      expect(VspTheme.light().extension<VspTextTiers>(), isNotNull);
      expect(VspTheme.dark().extension<VspTextTiers>(), isNotNull);
    });

    test('and the light theme carries the light set', () {
      expect(VspTheme.light().extension<VspTextTiers>(), VspTextTiers.light);
      expect(VspTheme.dark().extension<VspTextTiers>(), VspTextTiers.dark);
    });

    test('whose reading tiers differ, because the surface under them does', () {
      expect(VspTextTiers.light.primary, isNot(VspTextTiers.dark.primary));
      expect(VspTextTiers.light.secondary, isNot(VspTextTiers.dark.secondary));
    });

    test('and whose third tier is deliberately the same in both', () {
      // #64748B clears 4.76:1 on white and 3:1 on #0B1326, so one colour
      // serves both. Asserted rather than left to look like an oversight —
      // somebody will otherwise "fix" it into two.
      expect(VspTextTiers.light.tertiary, VspTextTiers.dark.tertiary);
    });

    test('and they are the token values, not new colours invented here', () {
      // If these drift, the palette file has stopped being the palette again,
      // which is the exact failure this whole change exists to undo.
      expect(VspTextTiers.dark.primary, VspColorDark.textPrimary);
      expect(VspTextTiers.dark.secondary, VspColorDark.textSecondary);
      expect(VspTextTiers.light.primary, VspColorLight.textPrimary);
      expect(VspTextTiers.light.secondary, VspColorLight.textSecondary);
    });

    testWidgets('with the dark set where a theme carries none', (tester) async {
      // A widget lifted into a bare MaterialApp — which is most widget tests —
      // keeps the colours it had rather than turning invisible.
      late VspTextTiers tiers;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              tiers = VspTextTiers.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(tiers, VspTextTiers.dark);
    });
  });

  group('a widget on a real screen', () {
    Future<Color> badgeTint(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: FreshnessBadge(
                dataFreshness: DataFreshness(
                  publishedAt: DateTime.utc(2026, 8, 16),
                  versionNumber: 1,
                  verificationStatus: VerificationStatus.verified,
                ),
              ),
            ),
          ),
        ),
      );
      // Not `pump()`. MaterialApp animates a theme change through
      // AnimatedTheme, so one frame after the switch the colours are still
      // most of the way back at the previous theme — which reads exactly like
      // a widget that ignores the theme, and cost a debugging detour saying
      // so.
      await tester.pumpAndSettle();
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(FreshnessBadge),
          matching: find.byType(Container),
        ).first,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('is tinted differently under each theme', (tester) async {
      // A widget that hardcodes a palette renders identically in both and
      // passes every test ever written about its content.
      expect(
        await badgeTint(tester, VspTheme.light()),
        isNot(await badgeTint(tester, VspTheme.dark())),
      );
    });
  });
}
