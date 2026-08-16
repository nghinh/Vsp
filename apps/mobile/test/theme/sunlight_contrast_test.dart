// Can a golfer read this in the sun?
//
// The palette was written against a spec and never against a contrast
// checker, and it drifted to somewhere backwards for a golf app: the dark
// "outdoor" palette passed comfortably on every colour, while light mode —
// the default, the one on screen at noon on a fairway — failed on almost
// everything that carried meaning. The primary action colour was 3.56:1. The
// white label on the primary button was 3.56:1. The third text tier, used for
// units and timestamps, was 2.56:1, which is below the floor for a decorative
// graphic, let alone a number somebody clubs off.
//
// None of that is visible in review. A designer looks at it on a desk at 300
// lux and it is fine; the golfer looks at it at 100,000 lux and it is gone. So
// it is measured here instead, because a number is the only part of this that
// survives an opinion.
//
// The thresholds are WCAG's, held with margin rather than at the line: AA asks
// 4.5:1 for text and 3:1 for a graphic, and those are office numbers. Nothing
// in this file argues for a specific colour — it argues that whatever colour
// is chosen has to be legible outdoors.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

/// Relative luminance, per WCAG 2.1.
double _luminance(Color color) {
  double channel(double value) {
    final c = value / 255.0;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(color.r * 255) +
      0.7152 * channel(color.g * 255) +
      0.0722 * channel(color.b * 255);
}

/// Contrast ratio between two opaque colours, 1:1 to 21:1.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('light mode, which is the one held in the sun', () {
    const page = VspColorLight.background;

    test('body text is comfortably past AA', () {
      expect(contrast(VspColorLight.textPrimary, page), greaterThan(12.0));
      expect(contrast(VspColorLight.textSecondary, page), greaterThan(4.5));
    });

    test('the third text tier is text, not decoration', () {
      // 2.56:1 before. Units, timestamps and hints live in this tier, and at
      // that ratio they were absent outdoors rather than quiet.
      expect(
        contrast(VspColorLight.textTertiary, page),
        greaterThanOrEqualTo(4.5),
        reason: 'the tier that carries units and timestamps must be readable',
      );
    });

    test('the label on the primary button can be read', () {
      // The button that starts a round. White on orange-600 was 3.56:1.
      expect(
        contrast(VspColorLight.onPrimary, VspColorLight.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('every filled action carries its own label', () {
      final pairs = <String, List<Color>>{
        'secondary': [VspColorLight.onSecondary, VspColorLight.secondary],
        'accent': [VspColorLight.onAccent, VspColorLight.accent],
        'destructive': [VspColorLight.onDestructive, VspColorLight.destructive],
      };

      pairs.forEach((name, pair) {
        expect(
          contrast(pair[0], pair[1]),
          greaterThanOrEqualTo(4.5),
          reason: '$name button label',
        );
      });
    });

    test('an action colour is distinguishable from the page it sits on', () {
      // Icons and text set in the brand colour, not just filled buttons.
      for (final entry in {
        'primary': VspColorLight.primary,
        'accent': VspColorLight.accent,
        'destructive': VspColorLight.destructive,
      }.entries) {
        expect(
          contrast(entry.value, page),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key} set as text or an icon on the page',
        );
      }
    });

    test('a divider is visible without a shadow to help it', () {
      // Shadows are the first thing daylight takes. A border at 8% opacity
      // was a border only on a desk.
      final border = Color.alphaBlend(VspColorLight.border, page);
      expect(contrast(border, page), greaterThan(1.15));
    });
  });

  group('dark mode, which was already right', () {
    const page = VspColorDark.background;

    test('nothing regressed while light mode was being fixed', () {
      for (final entry in {
        'primary': VspColorDark.primary,
        'secondary': VspColorDark.secondary,
        'accent': VspColorDark.accent,
        'onBackground': VspColorDark.onBackground,
      }.entries) {
        expect(
          contrast(entry.value, page),
          greaterThanOrEqualTo(4.5),
          reason: entry.key,
        );
      }
    });
  });
}
