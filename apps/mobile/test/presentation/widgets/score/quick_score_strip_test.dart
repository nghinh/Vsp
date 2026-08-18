// One tap for a score, and what that replaced.
//
// Recording a score is the most frequent action in this app — 18 holes times
// the size of the flight — and it had no one-tap path. The +/- controls walk
// one stroke at a time, so a 4 from nothing was four taps; the number opened
// a bottom sheet with a text field, the system keyboard, a 1-9 pad and a
// Confirm button, which is four interactions and a keyboard for a single
// digit.
//
// A golf score is not an arbitrary number: the hole's par says what to offer.
// These tests hold the offer — the right five numbers, the current entry
// visible, one tap to record — and the escape hatch for the hole that went
// wrong.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/widgets/score/quick_score_strip.dart';

void main() {
  Future<List<int>> pumpStrip(
    WidgetTester tester, {
    required int par,
    int? score,
    VoidCallback? onOther,
  }) async {
    final recorded = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuickScoreStrip(
            par: par,
            score: score,
            onScore: recorded.add,
            onOther: onOther ?? () {},
          ),
        ),
      ),
    );
    return recorded;
  }

  group('what a par 4 offers', () {
    testWidgets('birdie through triple, by the number a golfer writes', (
      tester,
    ) async {
      await pumpStrip(tester, par: 4);

      for (final number in ['3', '4', '5', '6', '7']) {
        expect(find.text(number), findsOneWidget, reason: number);
      }
    });

    testWidgets('named, so the number is not the only thing to read', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await pumpStrip(tester, par: 4);

      expect(find.text(l10n.scoreBirdie), findsOneWidget);
      expect(find.text(l10n.scorePar), findsOneWidget);
      expect(find.text(l10n.scoreBogey), findsOneWidget);
    });

    testWidgets('and it moves with the hole', (tester) async {
      // A par 3 offers 2 through 6, not 3 through 7. Getting this wrong hands
      // the golfer five buttons none of which is their score.
      await pumpStrip(tester, par: 3);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });
  });

  group('recording', () {
    testWidgets('takes exactly one tap', (tester) async {
      final recorded = await pumpStrip(tester, par: 4);

      await tester.tap(find.text('5'));
      await tester.pump();

      expect(recorded, [5]);
    });

    testWidgets('sets the score outright rather than stepping toward it', (
      tester,
    ) async {
      // The distinction that makes it one tap: this is setGrossScore, not
      // five increments.
      final recorded = await pumpStrip(tester, par: 5);

      await tester.tap(find.text('8'));
      await tester.pump();

      expect(recorded, [8]);
    });

    testWidgets('and changing a score is also one tap', (tester) async {
      final recorded = await pumpStrip(tester, par: 4, score: 5);

      await tester.tap(find.text('4'));
      await tester.pump();

      expect(recorded, [4]);
    });
  });

  group('the score already recorded', () {
    testWidgets('is marked, so the golfer can see their own entry', (
      tester,
    ) async {
      await pumpStrip(tester, par: 4, score: 5);

      expect(
        tester.getSemantics(find.text('5')).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
    });

    testWidgets('a score outside the strip marks the way out instead', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      // A 9 on a par 4. Nothing on the strip matches, and leaving every key
      // unmarked would read as no score entered at all.
      await pumpStrip(tester, par: 4, score: 9);

      expect(
        tester.getSemantics(find.text('…')).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(find.text(l10n.scoreOther), findsOneWidget);
    });

    testWidgets('nothing is marked before a score is entered', (tester) async {
      await pumpStrip(tester, par: 4);

      expect(
        tester.getSemantics(find.text('4')).hasFlag(SemanticsFlag.isSelected),
        isFalse,
      );
    });
  });

  group('the hole that went wrong', () {
    testWidgets('still has the keypad behind the last key', (tester) async {
      var opened = false;
      await pumpStrip(tester, par: 4, onOther: () => opened = true);

      await tester.tap(find.text('…'));
      await tester.pump();

      expect(opened, isTrue);
    });
  });

  group('the hand this is used by', () {
    testWidgets('every key clears the touch target minimum with room', (
      tester,
    ) async {
      await pumpStrip(tester, par: 4);

      // 44pt is the minimum for an index finger indoors. This is a thumb in a
      // glove, so the keys are taller than the floor rather than at it.
      for (final key in ['3', '4', '5', '6', '7', '…']) {
        final size = tester.getSize(
          find.ancestor(of: find.text(key), matching: find.byType(Container)).first,
        );
        expect(size.height, greaterThanOrEqualTo(56), reason: key);
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
      }
    });
  });
}
