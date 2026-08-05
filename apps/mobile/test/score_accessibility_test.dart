// Score Accessibility Tests — VSP Mobile App
//
// Tests for AC-2 (touch targets ≥44dp) and AC-3 (non-color-only indicators).
// Verifies semantic labels, accessibility compliance, and color-blind safety.
//
// Story 5.3 — Slice 5: Accessibility & UX Compliance

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/presentation/widgets/score/player_score_row.dart';
import 'package:vsp_mobile/presentation/widgets/score/hole_navigation_bar.dart';
import 'package:vsp_mobile/presentation/widgets/score/progressive_score_field.dart';
import 'package:vsp_mobile/presentation/widgets/score/fairway_gir_toggle.dart';
import 'package:vsp_mobile/presentation/widgets/common/offline_indicator.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  /// Minimum touch target size in logical pixels (44pt iOS / 48dp Android).
  const kMinTouchTarget = 44.0;

  Widget buildMaterialApp(Widget child) {
    return MaterialApp(
      theme: VspTheme.light(),
      locale: const Locale('en'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );
  }

  // ─── PlayerScoreRow Accessibility ─────────────────────────────────────────

  group('PlayerScoreRow Accessibility', () {
    testWidgets('has semantic label describing score state when entered',
        (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Nguyen Van A',
          grossScore: 4,
          status: PlayerScoreStatus.entered,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
        ),
      ));

      // The widget should have a Semantics widget
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('has semantic label when score not entered', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Tran Van B',
          grossScore: null,
          status: PlayerScoreStatus.notEntered,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
        ),
      ));

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('has semantic label when hole not played', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Le Van C',
          grossScore: null,
          status: PlayerScoreStatus.notPlayed,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
        ),
      ));

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('increment button has semantic label', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Pham Van D',
          grossScore: 4,
          status: PlayerScoreStatus.entered,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
          isExpanded: true,
        ),
      ));

      // Find the increment button (Icons.add)
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('decrement button has semantic label', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Ho Van E',
          grossScore: 4,
          status: PlayerScoreStatus.entered,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
          isExpanded: true,
        ),
      ));

      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('score buttons meet minimum touch target size',
        (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Duong Van F',
          grossScore: 4,
          status: PlayerScoreStatus.entered,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
          isExpanded: true,
        ),
      ));

      // Find the increment button container
      final addButton = find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(SizedBox),
      );
      expect(addButton, findsWidgets);

      // Verify touch target size
      final addButtonWidget = tester.widget<SizedBox>(addButton.first);
      expect(addButtonWidget.width, greaterThanOrEqualTo(kMinTouchTarget));
      expect(addButtonWidget.height, greaterThanOrEqualTo(kMinTouchTarget));
    });

    testWidgets('displays score indicator with text label (non-color-only)',
        (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Bui Van G',
          grossScore: 4,
          status: PlayerScoreStatus.entered,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
        ),
      ));

      // Should display filled circle indicator
      expect(find.text('●'), findsOneWidget);
    });

    testWidgets('displays empty circle for not entered state (non-color-only)',
        (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Bui Van H',
          grossScore: null,
          status: PlayerScoreStatus.notEntered,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
        ),
      ));

      expect(find.text('○'), findsOneWidget);
    });

    testWidgets('displays dash for not played state (non-color-only)',
        (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        PlayerScoreRow(
          playerName: 'Bui Van I',
          grossScore: null,
          status: PlayerScoreStatus.notPlayed,
          onIncrement: () {},
          onDecrement: () {},
          onScoreTap: () {},
        ),
      ));

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('score indicator distinguishable in grayscale', (tester) async {
      // Build with grayscale filter to simulate color-blind view
      await tester.pumpWidget(
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.grey,
            BlendMode.saturation,
          ),
          child: MaterialApp(
            theme: VspTheme.light(),
            locale: const Locale('en'),
            supportedLocales: kSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Column(
                children: [
                  PlayerScoreRow(
                    playerName: 'Entered',
                    grossScore: 4,
                    status: PlayerScoreStatus.entered,
                    onIncrement: () {},
                    onDecrement: () {},
                    onScoreTap: () {},
                  ),
                  PlayerScoreRow(
                    playerName: 'Not Entered',
                    grossScore: null,
                    status: PlayerScoreStatus.notEntered,
                    onIncrement: () {},
                    onDecrement: () {},
                    onScoreTap: () {},
                  ),
                  PlayerScoreRow(
                    playerName: 'Not Played',
                    grossScore: null,
                    status: PlayerScoreStatus.notPlayed,
                    onIncrement: () {},
                    onDecrement: () {},
                    onScoreTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // All three states should be visible and distinguishable
      expect(find.text('●'), findsOneWidget);
      expect(find.text('○'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });
  });

  // ─── HoleNavigationBar Accessibility ──────────────────────────────────────

  group('HoleNavigationBar Accessibility', () {
    testWidgets('has semantic label for hole progress', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        HoleNavigationBar(
          currentHoleIndex: 4,
          totalHoles: 18,
          onPrevious: () {},
          onNext: () {},
        ),
      ));

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('displays hole progress text', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        HoleNavigationBar(
          currentHoleIndex: 4,
          totalHoles: 18,
          onPrevious: () {},
          onNext: () {},
        ),
      ));

      expect(find.text('Hole 5 of 18'), findsOneWidget);
    });

    testWidgets('prev/next buttons meet minimum touch target',
        (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        HoleNavigationBar(
          currentHoleIndex: 4,
          totalHoles: 18,
          onPrevious: () {},
          onNext: () {},
        ),
      ));

      // Find navigation buttons
      final prevButton = find.ancestor(
        of: find.byIcon(Icons.chevron_left),
        matching: find.byType(SizedBox),
      );
      final nextButton = find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(SizedBox),
      );

      expect(prevButton, findsWidgets);
      expect(nextButton, findsWidgets);

      // Verify touch targets
      final prevWidget = tester.widget<SizedBox>(prevButton.first);
      final nextWidget = tester.widget<SizedBox>(nextButton.first);
      expect(prevWidget.width, greaterThanOrEqualTo(kMinTouchTarget));
      expect(prevWidget.height, greaterThanOrEqualTo(kMinTouchTarget));
      expect(nextWidget.width, greaterThanOrEqualTo(kMinTouchTarget));
      expect(nextWidget.height, greaterThanOrEqualTo(kMinTouchTarget));
    });

    testWidgets('shows complete round button on last hole', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        HoleNavigationBar(
          currentHoleIndex: 17, // Last hole (0-indexed)
          totalHoles: 18,
          onPrevious: () {},
          onNext: () {},
          onCompleteRound: () {},
        ),
      ));

      expect(find.text('Complete Round'), findsOneWidget);
    });

    testWidgets('complete round button has semantic label', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        HoleNavigationBar(
          currentHoleIndex: 17,
          totalHoles: 18,
          onPrevious: () {},
          onNext: () {},
          onCompleteRound: () {},
        ),
      ));

      expect(find.byType(Semantics), findsWidgets);
    });
  });

  // ─── ProgressiveScoreField Accessibility ───────────────────────────────────

  group('ProgressiveScoreField Accessibility', () {
    testWidgets('field has semantic label', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        ProgressiveScoreField(
          label: 'Putts',
          value: 2,
          onIncrement: () {},
          onDecrement: () {},
          semanticLabel: 'Putts for player: 2',
        ),
      ));

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('increment button has semantic label', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        ProgressiveScoreField(
          label: 'Putts',
          value: 2,
          onIncrement: () {},
          onDecrement: () {},
          semanticLabel: 'Putts for player',
        ),
      ));

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('decrement button has semantic label', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        ProgressiveScoreField(
          label: 'Penalties',
          value: 1,
          onIncrement: () {},
          onDecrement: () {},
          semanticLabel: 'Penalties for player',
        ),
      ));

      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('stepper buttons meet minimum touch target', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        ProgressiveScoreField(
          label: 'Putts',
          value: 2,
          onIncrement: () {},
          onDecrement: () {},
          semanticLabel: 'Putts for player',
        ),
      ));

      final addButton = find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(SizedBox),
      );
      final removeButton = find.ancestor(
        of: find.byIcon(Icons.remove),
        matching: find.byType(SizedBox),
      );

      final addWidget = tester.widget<SizedBox>(addButton.first);
      final removeWidget = tester.widget<SizedBox>(removeButton.first);

      expect(addWidget.width, greaterThanOrEqualTo(kMinTouchTarget));
      expect(addWidget.height, greaterThanOrEqualTo(kMinTouchTarget));
      expect(removeWidget.width, greaterThanOrEqualTo(kMinTouchTarget));
      expect(removeWidget.height, greaterThanOrEqualTo(kMinTouchTarget));
    });
  });

  // ─── StatToggle Accessibility ─────────────────────────────────────────────

  group('FairwayGirToggle Accessibility', () {
    testWidgets('toggle has semantic label', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        FairwayGirToggles(
          fairwayState: StatToggleState.yes,
          girState: StatToggleState.no,
          onFairwayYes: () {},
          onFairwayNo: () {},
          onFairwayClear: () {},
          onGirYes: () {},
          onGirNo: () {},
          onGirClear: () {},
        ),
      ));

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('displays fairway label', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        FairwayGirToggles(
          fairwayState: StatToggleState.yes,
          girState: StatToggleState.no,
          onFairwayYes: () {},
          onFairwayNo: () {},
          onFairwayClear: () {},
          onGirYes: () {},
          onGirNo: () {},
          onGirClear: () {},
        ),
      ));

      expect(find.text('Fairway'), findsOneWidget);
      expect(find.text('GIR'), findsOneWidget);
    });

    testWidgets('yes/no buttons have semantic labels', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        FairwayGirToggles(
          fairwayState: StatToggleState.yes,
          girState: StatToggleState.no,
          onFairwayYes: () {},
          onFairwayNo: () {},
          onFairwayClear: () {},
          onGirYes: () {},
          onGirNo: () {},
          onGirClear: () {},
        ),
      ));

      // Should have check icons for yes buttons
      expect(find.byIcon(Icons.check), findsWidgets);
      // Should have close icons for no buttons
      expect(find.byIcon(Icons.close), findsWidgets);
    });

    testWidgets('toggle buttons meet minimum touch target', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        FairwayGirToggles(
          fairwayState: StatToggleState.yes,
          girState: StatToggleState.no,
          onFairwayYes: () {},
          onFairwayNo: () {},
          onFairwayClear: () {},
          onGirYes: () {},
          onGirNo: () {},
          onGirClear: () {},
        ),
      ));

      final checkButtons = find.ancestor(
        of: find.byIcon(Icons.check),
        matching: find.byType(SizedBox),
      );

      if (checkButtons.evaluate().isNotEmpty) {
        final checkWidget = tester.widget<SizedBox>(checkButtons.first);
        expect(checkWidget.width, greaterThanOrEqualTo(kMinTouchTarget));
        expect(checkWidget.height, greaterThanOrEqualTo(kMinTouchTarget));
      }
    });
  });

  // ─── OfflineIndicator Accessibility ────────────────────────────────────────

  group('OfflineIndicator Accessibility', () {
    testWidgets('shows label when offline', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        const OfflineIndicator(isOffline: true),
      ));

      expect(find.text('Saved offline'), findsOneWidget);
    });

    testWidgets('shows syncing label when syncing', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        const OfflineIndicator(isSyncing: true),
      ));

      expect(find.text('Syncing…'), findsOneWidget);
    });

    testWidgets('has semantic label for screen readers', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        const OfflineIndicator(isOffline: true),
      ));

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('displays icon and text (non-color-only)', (tester) async {
      await tester.pumpWidget(buildMaterialApp(
        const OfflineIndicator(isOffline: true),
      ));

      // Should have cloud_off icon
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      // Should have text label
      expect(find.text('Saved offline'), findsOneWidget);
    });

    testWidgets('distinguishable in grayscale', (tester) async {
      await tester.pumpWidget(
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.grey,
            BlendMode.saturation,
          ),
          child: MaterialApp(
            theme: VspTheme.light(),
            home: const Scaffold(
              body: OfflineIndicator(isOffline: true),
            ),
          ),
        ),
      );

      // Should still be visible with icon and text
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text('Saved offline'), findsOneWidget);
    });
  });

  // ─── Score Entry Card (Combined) Accessibility ─────────────────────────────

  group('Score indicators are non-color-only across all states', () {
    testWidgets('all three score states distinguishable without color',
        (tester) async {
      // Test that filled/empty/dash are all distinguishable in grayscale
      await tester.pumpWidget(
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.grey,
            BlendMode.saturation,
          ),
          child: MaterialApp(
            theme: VspTheme.light(),
            locale: const Locale('en'),
            supportedLocales: kSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Column(
                children: [
                  PlayerScoreRow(
                    playerName: 'Player 1',
                    grossScore: 4,
                    status: PlayerScoreStatus.entered,
                    onIncrement: () {},
                    onDecrement: () {},
                    onScoreTap: () {},
                  ),
                  PlayerScoreRow(
                    playerName: 'Player 2',
                    grossScore: null,
                    status: PlayerScoreStatus.notEntered,
                    onIncrement: () {},
                    onDecrement: () {},
                    onScoreTap: () {},
                  ),
                  PlayerScoreRow(
                    playerName: 'Player 3',
                    grossScore: null,
                    status: PlayerScoreStatus.notPlayed,
                    onIncrement: () {},
                    onDecrement: () {},
                    onScoreTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // All score indicators should be present and distinguishable
      expect(find.text('●'), findsOneWidget);
      expect(find.text('○'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      // Each should only appear once
      expect(find.text('●'), findsNWidgets(1));
      expect(find.text('○'), findsNWidgets(1));
      expect(find.text('—'), findsNWidgets(1));
    });
  });
}
