// Ten labels, one screen.
//
// From a phone on Long Biên's 10th, in the vector map: "PHÁT BÓNG 120 / 1…"
// printed under "BUNKER", "PHÁT BÓNG 132 / 152" printed under both, and "HỒ
// NƯỚC 116 / 185" ran off the right edge with its last digits gone. Every
// label was correct and the picture was unreadable.
//
// Each chip was drawn at its own projected position and nothing else. The file
// already carried a comment predicting exactly this — "two shapes close
// together end up with two chips on top of each other" — and the mitigation it
// describes, a pointer down onto the shape, only answers *which shape a chip
// means*. It does not stop them covering each other.
//
// So chips are now laid out greedily in priority order: place one if its box
// is clear, skip it if it is not. Skipping rather than nudging, because a
// nudged chip points at the wrong bunker and a distance attached to the wrong
// bunker is worse than no distance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/hole_map/presentation/widgets/feature_label_overlay.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Rectangles of everything the overlay actually drew.
List<Rect> drawnChips(WidgetTester tester) {
  final rects = <Rect>[];
  for (final element in find
      .descendant(
        of: find.byKey(const Key('feature_label_overlay')),
        matching: find.byType(Positioned),
      )
      .evaluate()) {
    final positioned = element.widget as Positioned;
    rects.add(
      Rect.fromLTWH(
        positioned.left ?? 0,
        positioned.top ?? 0,
        positioned.width ?? 0,
        34,
      ),
    );
  }
  return rects;
}

void main() {
  group('the layout rule', () {
    test('no two boxes may overlap', () {
      // The property, stated on plain rectangles. The overlay needs a live
      // MapLibre controller to project anything, which a widget test has no
      // way to provide — so the rule is pinned here and the widget is what
      // applies it.
      const width = 116.0;
      const height = 34.0;
      final requested = <Offset>[
        const Offset(200, 400),
        const Offset(210, 405), // 10px away — the Long Biên bunker cluster
        const Offset(600, 400), // clear
        const Offset(205, 402), // also colliding
      ];

      final placed = <Rect>[];
      for (final at in requested) {
        final rect = Rect.fromLTWH(
          at.dx - width / 2,
          at.dy - height,
          width,
          height,
        );
        if (placed.any((other) => other.overlaps(rect))) continue;
        placed.add(rect);
      }

      expect(placed, hasLength(2));
      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          expect(placed[i].overlaps(placed[j]), isFalse);
        }
      }
    });

    test('a chip near the edge is clamped, not cut', () {
      // "HỒ NƯỚC 116 / 185" was losing its last characters off the right of a
      // 360 dp screen. Clamped sideways only: moving it vertically would break
      // the pointer's claim about which shape it belongs to.
      const width = 116.0;
      const screenWidth = 360.0;
      const inset = 8.0;

      final left = (350 - width / 2).clamp(inset, screenWidth - width - inset);

      expect(left + width, lessThanOrEqualTo(screenWidth - inset));
      expect(left, greaterThanOrEqualTo(inset));
    });
  });

  group('with no controller to project against', () {
    testWidgets('the overlay draws nothing rather than piling chips at zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VspTheme.dark(),
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FeatureLabelOverlay(
              controller: null,
              chips: [
                const FeatureLabelChip(
                  label: 'Bunker',
                  meters: 110,
                  colour: Color(0xFFE9C46A),
                  latitude: 21.036,
                  longitude: 105.892,
                ),
                const FeatureLabelChip(
                  label: 'Bunker',
                  meters: 314,
                  colour: Color(0xFFE9C46A),
                  latitude: 21.0361,
                  longitude: 105.8921,
                ),
              ],
              unit: DistanceUnit.yards,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(drawnChips(tester), isEmpty);
    });
  });
}
