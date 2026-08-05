// Accessible Bar Chart Widget Tests — VSP Mobile App
//
// Per Story 11.2 AC3: charts include legends, accessible colors, labels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/presentation/widgets/analytics/accessible_bar_chart.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  group('AccessibleBarChart', () {
    testWidgets('renders empty when groups is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AccessibleBarChart(
              groups: [],
              yAxisLabel: 'Shots',
              title: 'Test Chart',
            ),
          ),
        ),
      );
      // Renders without crashing on empty data, and shows no bar labels.
      expect(find.byType(AccessibleBarChart), findsOneWidget);
      expect(find.text('Driver'), findsNothing);
    });

    testWidgets('renders with valid groups', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AccessibleBarChart(
              groups: [
                BarChartGroup(
                  label: 'Driver',
                  values: [30.0],
                  patternName: 'driver',
                ),
                BarChartGroup(
                  label: '3 Wood',
                  values: [20.0],
                  patternName: '3wood',
                ),
              ],
              yAxisLabel: 'Shots',
              title: 'Club Usage',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render legend items
      expect(find.text('Driver'), findsWidgets);
      expect(find.text('3 Wood'), findsWidgets);
    });

    testWidgets('has semantic label for accessibility', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: AccessibleBarChart(
              groups: [
                BarChartGroup(
                  label: 'Driver',
                  values: [30.0],
                  patternName: 'driver',
                ),
              ],
              yAxisLabel: 'Shots',
              title: 'Club Usage Chart',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the Semantics widget with the title label
      final semantics = find.bySemanticsLabel('Club Usage Chart');
      expect(semantics, findsOneWidget);
    });

    test('BarChartGroup constructor works', () {
      final group = BarChartGroup(
        label: 'Driver',
        values: [30.0, 15.0],
        patternName: 'driver',
      );
      expect(group.label, 'Driver');
      expect(group.values.length, 2);
      expect(group.patternName, 'driver');
    });
  });
}
