// Accessible Pie Chart Widget Tests — VSP Mobile App
//
// Per Story 11.2 AC3: charts include legends, accessible colors, labels,
// and non-color indicators.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/presentation/widgets/analytics/accessible_pie_chart.dart';

void main() {
  group('AccessiblePieChart', () {
    testWidgets('renders empty when sections is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessiblePieChart(sections: [], title: 'Test Pie'),
          ),
        ),
      );
      // Empty chart renders empty SizedBox
      expect(find.byType(AccessiblePieChart), findsOneWidget);
    });

    testWidgets('renders with valid sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessiblePieChart(
              sections: const [
                PieChartSection(
                  label: 'Fairway',
                  value: 70,
                  patternName: 'fairway',
                ),
                PieChartSection(
                  label: 'Rough',
                  value: 20,
                  patternName: 'rough',
                ),
                PieChartSection(
                  label: 'Bunker',
                  value: 10,
                  patternName: 'bunker',
                ),
              ],
              title: 'Lie Distribution',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Legend should show labels
      expect(find.textContaining('Fairway'), findsWidgets);
      expect(find.textContaining('Rough'), findsWidgets);
      expect(find.textContaining('Bunker'), findsWidgets);
    });

    testWidgets('has semantic label for accessibility', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessiblePieChart(
              sections: const [
                PieChartSection(
                  label: 'Fairway',
                  value: 70,
                  patternName: 'fairway',
                ),
              ],
              title: 'Lie Distribution Pie Chart',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final semantics = find.bySemanticsLabel('Lie Distribution Pie Chart');
      expect(semantics, findsOneWidget);
    });

    test('PieChartSection constructor works', () {
      const section = PieChartSection(
        label: 'Fairway',
        value: 70,
        patternName: 'fairway',
      );
      expect(section.label, 'Fairway');
      expect(section.value, 70);
      expect(section.patternName, 'fairway');
    });

    testWidgets('shows percentage in legend when sections provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessiblePieChart(
              sections: const [
                PieChartSection(
                  label: 'Fairway',
                  value: 70,
                  patternName: 'fairway',
                ),
                PieChartSection(
                  label: 'Rough',
                  value: 30,
                  patternName: 'rough',
                ),
              ],
              title: 'Test',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show 70% and 30% in legend
      expect(find.textContaining('70.0%'), findsWidgets);
      expect(find.textContaining('30.0%'), findsWidgets);
    });
  });
}
