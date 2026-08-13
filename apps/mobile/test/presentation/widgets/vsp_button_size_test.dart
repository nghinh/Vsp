import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/components/vsp_button.dart';

/// The button centred its label with a bare Center, which claims every point of
/// height on offer. A bottom bar, a sheet or a Stack offers the whole screen, so
/// the single "Tạo tài khoản" call to action on the phone registration form grew
/// to the full height of the display and painted over the form behind it — a
/// golfer saw one orange slab and no fields. These tests hold the button to the
/// height of its own label wherever the height it is given is merely an offer,
/// while leaving the two things callers do rely on intact: it still spreads
/// across the width it is handed, and a caller who fixes the height still gets
/// exactly that height.
void main() {
  Future<void> pumpIn(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );
  }

  const label = 'Tạo tài khoản';

  testWidgets('sizes to its label when the height is only an offer', (
    tester,
  ) async {
    // Loose bounded constraints — what a bottom bar, a bottom sheet or an
    // Align hands its child: up to 800 points tall, but nothing required.
    await pumpIn(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 800),
          child: const VspButton(label: label, size: VspButtonSize.large),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(VspButton)).height,
      lessThan(100),
      reason: 'the button swallowed the screen instead of sizing to its label',
    );
  });

  testWidgets('still spreads across the width it is offered', (tester) async {
    // Every full-width call to action in the app relies on this: the button is
    // dropped into a Column or a SizedBox(width: double.infinity) and expected
    // to reach both gutters, not to shrink to the width of its text.
    await pumpIn(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 800),
          child: const VspButton(label: label),
        ),
      ),
    );

    expect(tester.getSize(find.byType(VspButton)).width, 360);
  });

  testWidgets('honours a height a caller actually insists on', (tester) async {
    // A tight constraint is a decision, not an offer. A caller who wraps the
    // button in a fixed-height box, or drops it into an Expanded, still gets
    // the height they asked for.
    await pumpIn(
      tester,
      const SizedBox(
        width: 300,
        height: 120,
        child: VspButton(label: label),
      ),
    );

    expect(tester.getSize(find.byType(VspButton)), const Size(300, 120));
  });

  testWidgets('keeps the 44 point touch target on a short label', (
    tester,
  ) async {
    // Shrink-wrapping must not shrink past the minimum touch target, or the
    // button becomes hard to hit for anyone with less than steady hands.
    await pumpIn(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 800),
          child: const VspButton(label: 'OK', size: VspButtonSize.small),
        ),
      ),
    );

    final size = tester.getSize(find.byType(VspButton));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.height, lessThan(100));
  });

  testWidgets('does not stretch while loading either', (tester) async {
    // The loading state swaps the label for a spinner and takes the same
    // centring path, so it can regrow independently of the resting state.
    await pumpIn(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 800),
          child: const VspButton(label: label, isLoading: true),
        ),
      ),
    );

    expect(tester.getSize(find.byType(VspButton)).height, lessThan(100));
  });
}
