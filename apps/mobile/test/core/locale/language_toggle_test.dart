// The language switch, before sign-in.
//
// It lived one screen inside Settings, and Settings is behind sign-in. A
// golfer handed this app in a language they do not read had to read the
// sign-in screen in order to get past it and change the language. The one
// screen that genuinely needs the control is the first one.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/core/locale/language_toggle.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

Future<LocaleCubit> pumpToggle(
  WidgetTester tester, {
  Locale locale = const Locale('vi'),
}) async {
  final cubit = LocaleCubit();
  addTearDown(cubit.close);

  await tester.pumpWidget(
    BlocProvider<LocaleCubit>.value(
      value: cubit,
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (context, selected) => MaterialApp(
          theme: VspTheme.dark(),
          locale: selected ?? locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: LanguageToggle())),
        ),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

void main() {
  group('the language names', () {
    testWidgets('are written in their own language, whatever the app is in', (
      tester,
    ) async {
      // The rule this exists for: somebody who cannot read the current
      // language must still recognise their own. Translating "Vietnamese"
      // into Vietnamese would make the picker useless to the one person who
      // needs it.
      for (final locale in const [Locale('vi'), Locale('en')]) {
        await pumpToggle(tester, locale: locale);
        expect(find.text('Tiếng Việt'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
      }
    });
  });

  group('choosing a language', () {
    testWidgets('takes one tap and applies immediately', (tester) async {
      final cubit = await pumpToggle(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(cubit.state?.languageCode, 'en');
    });

    testWidgets('and switching back is one tap too', (tester) async {
      final cubit = await pumpToggle(tester, locale: const Locale('en'));

      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      expect(cubit.state?.languageCode, 'vi');
    });
  });

  group('the current language', () {
    testWidgets('is marked even before anybody has chosen one', (tester) async {
      // The cubit starts null — "follow the device" — and a toggle showing
      // neither option selected reads as broken. It highlights whichever
      // language is actually on screen.
      await pumpToggle(tester, locale: const Locale('vi'));

      expect(
        tester
            .getSemantics(find.text('Tiếng Việt'))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.text('English'))
            .hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );
    });

    testWidgets('follows the choice once one is made', (tester) async {
      await pumpToggle(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(
        tester
            .getSemantics(find.text('English'))
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
    });
  });

  group('the hand it is used by', () {
    testWidgets('each option clears the touch minimum', (tester) async {
      await pumpToggle(tester);

      for (final label in ['Tiếng Việt', 'English']) {
        final size = tester.getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(36), reason: label);
        expect(size.width, greaterThanOrEqualTo(44), reason: label);
      }
    });
  });
}
