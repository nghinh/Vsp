// Settings / language switching tests.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/features/settings/presentation/settings_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness(LocaleCubit cubit) {
    return BlocProvider.value(
      value: cubit,
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (context, locale) => MaterialApp(
          locale: locale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SettingsScreen(),
        ),
      ),
    );
  }

  testWidgets('shows the three language options', (tester) async {
    final cubit = LocaleCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(harness(cubit));

    expect(find.text('System default'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
  });

  testWidgets('picking Vietnamese switches the UI language', (tester) async {
    final cubit = LocaleCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(harness(cubit));
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();

    expect(cubit.state, const Locale('vi'));
    // The screen itself re-renders in Vietnamese.
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Theo thiết bị'), findsOneWidget);
  });

  testWidgets('the choice is persisted and restored', (tester) async {
    final cubit = LocaleCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(harness(cubit));

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();

    final restored = LocaleCubit();
    addTearDown(restored.close);
    await restored.load();
    expect(restored.state, const Locale('vi'));
  });

  testWidgets('switching back to English restores English copy', (
    tester,
  ) async {
    final cubit = LocaleCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(harness(cubit));

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(cubit.state, const Locale('en'));
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('system default clears the stored preference', (tester) async {
    final cubit = LocaleCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(harness(cubit));

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theo thiết bị'));
    await tester.pumpAndSettle();

    expect(cubit.state, isNull);
    final restored = LocaleCubit();
    addTearDown(restored.close);
    await restored.load();
    expect(restored.state, isNull);
  });
}
