// A disabled button has to look disabled all the way round.
//
// The theme handed OutlinedButton a single BorderSide for every state, so a
// disabled button kept a full-strength primary border while Material greyed
// its label and icon. The round summary of a round with no scores is where
// this shows: "Sửa điểm" and "Chia sẻ" outlined in brand orange with pale
// grey text inside — in both palettes, on a screen a golfer reaches at the
// end of every round.
//
// Asserted against the brand colour rather than a hex: the point is not which
// grey the border goes, it is that it stops being the colour that means tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

Color _borderOf(WidgetTester tester) {
  final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
  final style = button.style ?? const ButtonStyle();
  final resolved =
      style.side ??
      Theme.of(tester.element(find.byType(OutlinedButton))).outlinedButtonTheme
          .style!
          .side!;
  final states = button.onPressed == null
      ? <WidgetState>{WidgetState.disabled}
      : <WidgetState>{};
  return resolved.resolve(states)!.color;
}

Future<void> _pump(
  WidgetTester tester, {
  required ThemeData theme,
  required bool enabled,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: OutlinedButton(
          onPressed: enabled ? () {} : null,
          child: const Text('Sửa điểm'),
        ),
      ),
    ),
  );
}

void main() {
  for (final entry in {'light': VspTheme.light(), 'dark': VspTheme.dark()}
      .entries) {
    group('the ${entry.key} palette', () {
      testWidgets('outlines a live button in the colour that means tap', (
        tester,
      ) async {
        await _pump(tester, theme: entry.value, enabled: true);
        expect(_borderOf(tester), entry.value.colorScheme.primary);
      });

      testWidgets('dims the border of a button nobody can press', (
        tester,
      ) async {
        await _pump(tester, theme: entry.value, enabled: false);

        final border = _borderOf(tester);
        expect(
          border,
          isNot(entry.value.colorScheme.primary),
          reason: 'a dead button must not wear the live border',
        );
        // And it is dimmed, not merely a different hue — the label beside it
        // is drawn at a fraction of full opacity, and the two have to agree.
        expect(border.opacity, lessThan(1.0));
      });
    });
  }
}
