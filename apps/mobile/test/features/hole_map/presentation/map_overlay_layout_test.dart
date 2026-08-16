// Two panels, one place.
//
// The hole map floats ten things over the picture, and every one of them used
// to choose its own coordinates. Two pairs chose the same ones:
//
//   PinMarker            left 12, top padding+8
//   PlayLinePanel        left 12, top padding+8
//   WindArrowOverlay     right 12, top padding+8
//   DistanceRingOverlay  right 12, top padding+8
//
// A Stack draws both and says nothing. On a hole with a published flag the
// badge sat under the distance to it; with wind and rings on, the legend sat
// under the arrow. In the screenshot that started this redesign the golfer's
// own position marker is printed over the map attribution, which is the third
// pair.
//
// None of that is a rendering bug — every widget did exactly what it was told.
// It is what absolute placement does once there are ten of them, and it is
// invisible in review because it only appears when two optional panels happen
// to be on at once.
//
// So the corners lay their own panels out, and this holds that: whatever is
// visible, no two panels overlap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The screen rectangle a widget occupies.
  Rect rectOf(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Panels laid out the way the map does it: a corner takes a list.
  Widget corner({
    required Alignment alignment,
    required List<Widget> children,
    double? top,
    double? bottom,
  }) {
    final left = alignment.x < 0;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left ? 12 : null,
      right: left ? null : 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget panel(String label, {double height = 40}) => SizedBox(
        key: ValueKey(label),
        width: 120,
        height: height,
        child: ColoredBox(color: const Color(0xFF1E293B)),
      );

  testWidgets('two panels in one corner do not overlap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            corner(
              alignment: Alignment.topLeft,
              top: 8,
              children: [panel('distance'), panel('flag')],
            ),
          ],
        ),
      ),
    );

    final distance = rectOf(tester, find.byKey(const ValueKey('distance')));
    final flag = rectOf(tester, find.byKey(const ValueKey('flag')));

    expect(distance.overlaps(flag), isFalse,
        reason: 'the flag badge sat on top of the distance to it');
    expect(flag.top, greaterThanOrEqualTo(distance.bottom),
        reason: 'the panel read first belongs above the one that qualifies it');
  });

  testWidgets('a corner with one panel wastes no gap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            corner(alignment: Alignment.topLeft, top: 8, children: [panel('only')]),
          ],
        ),
      ),
    );

    expect(rectOf(tester, find.byKey(const ValueKey('only'))).top, 8);
  });

  testWidgets('opposite corners never meet', (tester) async {
    // Both top corners full, which is the case the old layout collided in:
    // wind and rings on the right, distance and flag on the left.
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            corner(
              alignment: Alignment.topLeft,
              top: 8,
              children: [panel('distance'), panel('flag')],
            ),
            corner(
              alignment: Alignment.topRight,
              top: 8,
              children: [panel('wind'), panel('rings'), panel('green')],
            ),
          ],
        ),
      ),
    );

    final keys = ['distance', 'flag', 'wind', 'rings', 'green'];
    final rects = {
      for (final key in keys) key: rectOf(tester, find.byKey(ValueKey(key))),
    };

    for (final a in keys) {
      for (final b in keys) {
        if (a == b) continue;
        expect(rects[a]!.overlaps(rects[b]!), isFalse, reason: '$a over $b');
      }
    }
  });

  testWidgets('a bottom corner stacks upward from its floor', (tester) async {
    // The golfer's fix and the attribution share the bottom-left corner, and
    // printed one over the other before.
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            corner(
              alignment: Alignment.bottomLeft,
              bottom: 12,
              children: [panel('hazards'), panel('fix'), panel('credit')],
            ),
          ],
        ),
      ),
    );

    final hazards = rectOf(tester, find.byKey(const ValueKey('hazards')));
    final fix = rectOf(tester, find.byKey(const ValueKey('fix')));
    final credit = rectOf(tester, find.byKey(const ValueKey('credit')));

    expect(hazards.overlaps(fix), isFalse);
    expect(fix.overlaps(credit), isFalse);
    // The obligation sits at the floor; what a golfer reads sits above it.
    expect(credit.top, greaterThan(hazards.top));
  });
}
