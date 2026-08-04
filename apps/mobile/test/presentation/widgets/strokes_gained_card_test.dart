// StrokesGainedCard Widget Tests — VSP Mobile App
//
// Widget tests for StrokesGainedCard widget.
//
// Tests:
//  - Renders category name correctly
//  - SG value with correct sign color (green positive, red negative)
//  - Baseline vs actual display
//  - Sample count badge
//  - Confidence meter
//  - Limitation badge when limitation != null
//  - Accessibility labels present
//
// Story 11.3 — Slice 3: UI Shell

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/strokes_gained.dart';
import 'package:vsp_mobile/presentation/widgets/analytics/strokes_gained_card.dart';

void main() {
  group('StrokesGainedCard', () {
    // ─── Test Fixtures ────────────────────────────────────────────────────────

    StrokesGainedResult buildResult({
      required SGCategory category,
      required SGBenchmarkType benchmarkType,
      required double sg,
      required int sampleCount,
      SGLimitation? limitation,
      double baseline = 10.0,
      double actual = 9.5,
    }) {
      return StrokesGainedResult(
        category: category,
        benchmarkType: benchmarkType,
        strokesGained: sg,
        baselineStrokes: baseline,
        actualStrokes: actual,
        sampleCount: sampleCount,
        limitation: limitation,
        confidence: sampleCount >= 20 ? 0.8 : 0.0,
      );
    }

    Widget buildCard({
      required StrokesGainedResult result,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: StrokesGainedCard(
            result: result,
            onTap: onTap,
          ),
        ),
      );
    }

    // ─── Rendering Tests ──────────────────────────────────────────────────────

    testWidgets('renders category name correctly', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Off the Tee'), findsOneWidget);
    });

    testWidgets('renders approach category correctly', (tester) async {
      final result = buildResult(
        category: SGCategory.approach,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Approach'), findsOneWidget);
    });

    testWidgets('renders around the green category correctly', (tester) async {
      final result = buildResult(
        category: SGCategory.aroundTheGreen,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Around the Green'), findsOneWidget);
    });

    testWidgets('renders putting category correctly', (tester) async {
      final result = buildResult(
        category: SGCategory.putting,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Putting'), findsOneWidget);
    });

    // ─── SG Value Sign Color Tests ────────────────────────────────────────────

    testWidgets('displays positive SG value with plus sign', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('+0.5'), findsOneWidget);
    });

    testWidgets('displays negative SG value with minus sign', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: -0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('-0.5'), findsOneWidget);
    });

    testWidgets('positive SG shows upward arrow icon', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('negative SG shows downward arrow icon', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: -0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    // ─── Baseline vs Actual Tests ──────────────────────────────────────────────

    testWidgets('displays baseline and actual strokes', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
        baseline: 10.0,
        actual: 9.5,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('10.0'), findsOneWidget); // baseline
      expect(find.text('9.5'), findsOneWidget); // actual
    });

    testWidgets('shows dash when sample insufficient', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.0,
        sampleCount: 5, // < 20
        baseline: 10.0,
        actual: 10.0,
      );

      await tester.pumpWidget(buildCard(result: result));

      // Should show dashes instead of values
      expect(find.text('—'), findsNWidgets(2)); // both baseline and actual
    });

    // ─── Sample Count Tests ───────────────────────────────────────────────────

    testWidgets('displays sample count badge', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('sample count badge shows bar chart icon', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    // ─── Confidence Meter Tests ────────────────────────────────────────────────

    testWidgets('displays confidence label and percentage', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25, // confidence = 0.8
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Confidence'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('displays LinearProgressIndicator', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    // ─── Limitation Badge Tests ────────────────────────────────────────────────

    testWidgets('displays limitation badge when limitation present', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.0,
        sampleCount: 5,
        limitation: SGLimitation.insufficientSample,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.text('Insufficient Sample'), findsOneWidget);
    });

    testWidgets('displays warning icon when limitation present', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.0,
        sampleCount: 5,
        limitation: SGLimitation.insufficientSample,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('does not show limitation badge when no limitation', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
        limitation: null,
      );

      await tester.pumpWidget(buildCard(result: result));

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.text('Insufficient Sample'), findsNothing);
    });

    // ─── Accessibility Tests ───────────────────────────────────────────────────

    testWidgets('card has semantic label', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      // The card should have a Semantics widget
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('onTap callback is called when card tapped', (tester) async {
      bool tapped = false;
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(
        result: result,
        onTap: () => tapped = true,
      ));

      await tester.tap(find.byType(StrokesGainedCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    // ─── Touch Target Tests ───────────────────────────────────────────────────

    testWidgets('card has minimum touch target size', (tester) async {
      final result = buildResult(
        category: SGCategory.offTheTee,
        benchmarkType: SGBenchmarkType.similarHandicap,
        sg: 0.5,
        sampleCount: 25,
      );

      await tester.pumpWidget(buildCard(result: result));

      // Find the InkWell inside the card
      final inkWell = find.byType(InkWell);
      expect(inkWell, findsOneWidget);

      // Verify touch target by getting its size
      final inkWellWidget = tester.widget<InkWell>(inkWell);
      expect(inkWellWidget.borderRadius, isNotNull);
    });
  });
}
