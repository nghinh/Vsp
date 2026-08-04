// Design Tokens — Typography (Flutter)
//
// Source: packages/design-tokens/tokens/typography.yaml
// Platform: Flutter — Typography token mappings.

import 'package:flutter/material.dart';

// ─── Font Families ───────────────────────────────────────────────────────────

/// Font families — sourced from ux-spec §4.3 (Fira Sans + Fira Code).
abstract final class VspFontFamily {
  static const String display = 'Fira Sans';
  static const String body = 'Fira Sans';
  static const String mono = 'Fira Code';
}

// ─── Font Sizes ───────────────────────────────────────────────────────────────

/// Font size scale — sourced from ux-spec §4.3.
abstract final class VspFontSize {
  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16; // Minimum body text per UX spec
  static const double lg = 18;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double xl3 = 30;
  static const double xl4 = 36;
  static const double xl5 = 48;
  static const double xl6 = 60;
  static const double xl7 = 72;
}

// ─── Line Heights ─────────────────────────────────────────────────────────────

/// Line height values — sourced from ux-spec §4.3.
abstract final class VspLineHeight {
  static const double tight = 1.2; // Large numeric distance panels
  static const double snug = 1.375;
  static const double normal = 1.5; // Body text
  static const double relaxed = 1.625;
  static const double loose = 2.0;
}

// ─── Letter Spacing ───────────────────────────────────────────────────────────

/// Letter spacing values — sourced from ux-spec §4.3.
abstract final class VspLetterSpacing {
  static const double tighter = -0.8;
  static const double tight = -0.4;
  static const double normal = 0.0;
  static const double wide = 0.4;
  static const double wider = 0.8;
  static const double widest = 1.6;
}

// ─── Font Weights ─────────────────────────────────────────────────────────────

/// Font weight values — sourced from ux-spec §4.3.
abstract final class VspFontWeight {
  static const FontWeight thin = FontWeight.w100;
  static const FontWeight extralight = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;
}

// ─── Scale Ratios (Large Text Support) ───────────────────────────────────────

/// Large text scale ratios — sourced from ux-spec §4.3 / typography.yaml.
/// Multipliers applied to fontSize.base (16px) for Dynamic Type modes.
abstract final class VspScaleRatio {
  /// Small increase — accessibility small setting.
  static const double small = 1.25;

  /// Default large-text scaling.
  static const double medium = 1.5;

  /// Maximum supported scaling.
  static const double large = 2.0;
}

// ─── Text Tier Presets ────────────────────────────────────────────────────────

/// Text style presets — each maps to a complete TextStyle.
/// Use via VspTextStyles accessor to get resolved styles respecting
/// MediaQuery.boldTextOf(context) for large-text mode.
abstract final class VspTextStyles {
  /// Display — primary on-course distance numbers (sunlight readability).
  /// Fira Sans 48px bold, line-height 1.2.
  static TextStyle display(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.display,
    fontSize: _scaled(context, VspFontSize.xl5),
    height: VspLineHeight.tight,
    fontWeight: VspFontWeight.bold,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Heading — screen titles, section headers.
  /// Fira Sans 30px semibold, line-height 1.2.
  static TextStyle heading(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.display,
    fontSize: _scaled(context, VspFontSize.xl3),
    height: VspLineHeight.tight,
    fontWeight: VspFontWeight.semibold,
  );

  /// Title — card titles, nav items.
  /// Fira Sans 20px semibold, line-height 1.375.
  static TextStyle title(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.display,
    fontSize: _scaled(context, VspFontSize.xl),
    height: VspLineHeight.snug,
    fontWeight: VspFontWeight.semibold,
  );

  /// Body — standard body text, minimum 4.5:1 contrast.
  /// Fira Sans 16px regular, line-height 1.5.
  static TextStyle body(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.body,
    fontSize: _scaled(context, VspFontSize.base),
    height: VspLineHeight.normal,
    fontWeight: VspFontWeight.regular,
  );

  /// Body small — smaller body text.
  /// Fira Sans 14px regular, line-height 1.5.
  static TextStyle bodySmall(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.body,
    fontSize: _scaled(context, VspFontSize.sm),
    height: VspLineHeight.normal,
    fontWeight: VspFontWeight.regular,
  );

  /// Label — form labels, button text.
  /// Fira Sans 14px medium, letter-spacing 0.4.
  static TextStyle label(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.body,
    fontSize: _scaled(context, VspFontSize.sm),
    height: VspLineHeight.snug,
    fontWeight: VspFontWeight.medium,
    letterSpacing: VspLetterSpacing.wide,
  );

  /// Caption — helper text, timestamps (3:1 contrast minimum).
  /// Fira Sans 12px regular, line-height 1.5.
  static TextStyle caption(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.body,
    fontSize: _scaled(context, VspFontSize.xs),
    height: VspLineHeight.normal,
    fontWeight: VspFontWeight.regular,
  );

  /// Mono — distances, coordinates, technical metrics.
  /// Fira Code 16px regular, tabular figures for numeric precision.
  static TextStyle mono(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.mono,
    fontSize: _scaled(context, VspFontSize.base),
    height: VspLineHeight.normal,
    fontWeight: VspFontWeight.regular,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Distance display — extra-large monospace for on-course distance numbers.
  /// Fira Code, very large, tight leading, tabular figures.
  /// Respects bold text mode and high contrast.
  static TextStyle distanceDisplay(BuildContext context) => TextStyle(
    fontFamily: VspFontFamily.mono,
    fontSize: _scaled(context, VspFontSize.xl5),
    height: VspLineHeight.tight,
    fontWeight: VspFontWeight.bold,
    fontFeatures: const [
      FontFeature.tabularFigures(),
      FontFeature.enable('tnum'),
    ],
  );

  /// Apply MediaQuery.boldTextOf scaling factor to a size value.
  /// This ensures Dynamic Type / large text mode scales appropriately.
  ///
  /// Note: Flutter's [MediaQuery.boldTextOf] is a binary flag (on/off), not a
  /// scale-factor selector. It does not distinguish between "medium" (1.5x) and
  /// "large" (2.0x) accessibility text sizes. Per the UX spec §4.3 scale ratios,
  /// [VspScaleRatio.small] (1.25x) maps to the smallest accessibility setting,
  /// [VspScaleRatio.medium] (1.5x) maps to the default bold-text setting, and
  /// [VspScaleRatio.large] (2.0x) is reserved for future use when Flutter exposes
  /// a granular large-text scale factor. Currently, boldText=true → medium.
  static double _scaled(BuildContext context, double size) {
    final boldText = MediaQuery.boldTextOf(context);
    if (boldText) {
      // Use medium scale ratio (1.5x) for bold text mode.
      // VspScaleRatio.large (2.0x) is not consumed here because
      // Flutter's boldTextOf is binary and does not expose a larger scale.
      return size * VspScaleRatio.medium;
    }
    return size;
  }
}
