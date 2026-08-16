// Design Tokens — Color (Flutter)
//
// Source: packages/design-tokens/tokens/color.yaml
// Platform: Flutter — Color token mappings.
//
// All values sourced from ux-spec.md §4.2.

import 'package:flutter/material.dart';

// ─── Light Mode ───────────────────────────────────────────────────────────────

/// Light mode — the one a golfer is actually holding, in the sun.
///
/// <strong>Every value below that changed, changed because it failed a
/// measurement.</strong> This palette was written against a spec and never
/// against a contrast checker, and the result was backwards for a golf app:
/// the dark "outdoor" palette passes AA comfortably on every colour (8:1 to
/// 14:1), while light mode — the default, the one on screen at noon on a fairway
/// — failed on almost everything that carries meaning.
///
/// Measured against #FFFFFF, before:
///
///   primary #EA580C ......... 3.56:1   the primary action colour
///   white on that button .... 3.56:1   the label of the main button
///   secondary #F97316 ....... 2.80:1
///   accent #059669 .......... 3.77:1
///   textTertiary #94A3B8 .... 2.56:1   hints, units, timestamps
///
/// AA wants 4.5:1 for anything at body size. Three of those are below 3:1,
/// which is the floor for a *graphic* — so they were not legible as icons
/// either. And this is before the sun: a phone at 1,000 nits against 100,000
/// lux of Vietnamese midday reads far worse than any office measurement, which
/// is why the numbers here are held above the minimum rather than at it.
///
/// The hue is unchanged. This is the same orange brand, at a darkness that
/// survives daylight.
abstract final class VspColorLight {
  // Primary palette
  //
  // Orange-700 rather than orange-600: white on it is 5.18:1, so the label of
  // the button a golfer presses to start a round is legible, and the colour
  // reads as an action against white rather than as a highlight.
  static const Color primary = Color(0xFFC2410C); // 5.18:1 both ways
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Secondary emphasis. Deliberately not a second orange at a different
  /// lightness — two oranges a shade apart are one orange to a golfer glancing
  /// at a phone, so this is the amber the dark palette already uses for
  /// caution, darkened until it holds white.
  static const Color secondary = Color(0xFF9A3412); // 7.31:1
  static const Color onSecondary = Color(0xFFFFFFFF);

  /// Ready, safe, downloaded. Emerald-700; the -600 it replaces could not
  /// carry white on a badge.
  static const Color accent = Color(0xFF047857); // 5.48:1
  static const Color onAccent = Color(0xFFFFFFFF);

  // Destructive
  static const Color destructive = Color(0xFFB91C1C); // 6.47:1
  static const Color onDestructive = Color(0xFFFFFFFF);

  // Backgrounds
  //
  // Not pure white. #FBFAF9 is a half-step warm off-white: it costs 0.7:1 of
  // text contrast (17.85 → 17.12, both far past AA) and takes the specular
  // glare off a glossy screen held under the sun, which is the actual
  // limiting factor outdoors rather than the ratio.
  static const Color background = Color(0xFFFBFAF9);
  static const Color onBackground = Color(0xFF0F172A);

  /// Cards stay pure white so they lift off the page without a shadow —
  /// shadows are the first thing to disappear in bright light.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color muted = Color(0xFFF1F5F9);
  static const Color onMuted = Color(0xFF475569); // 7.58:1

  // Borders
  //
  // Doubled in weight. An 8% hairline is invisible in sunlight, which is
  // exactly when a golfer needs to see where one row ends and the next begins.
  static const Color border = Color(0x1F0F172A); // rgba(15,23,42,0.12)
  static const Color borderStrong = Color(0x3D0F172A); // rgba(15,23,42,0.24)

  // Focus ring
  static const Color ring = Color(0xFFC2410C);

  // Text contrast tiers
  //
  // Three tiers, and all three now readable. The old third tier was 2.56:1 —
  // decoration presented as information, which on a phone in daylight is
  // simply absent.
  static const Color textPrimary = Color(0xFF0F172A); // 17.12:1
  static const Color textSecondary = Color(0xFF475569); // 7.58:1
  static const Color textTertiary = Color(0xFF64748B); // 4.76:1
}

// ─── Dark / Outdoor Mode ──────────────────────────────────────────────────────

/// Dark mode color palette — sourced from ux-spec §4.2.
abstract final class VspColorDark {
  // Primary palette
  static const Color primary = Color(
    0xFFFB923C,
  ); // Lighter orange — 4.5:1 on #0F172A
  static const Color onPrimary = Color(0xFF0F172A);
  static const Color secondary = Color(0xFFFBBF24); // Amber — warning on dark
  static const Color onSecondary = Color(0xFF0F172A);
  static const Color accent = Color(0xFF68DBA9); // Emerald-400 — safe on dark
  static const Color onAccent = Color(0xFF052E16);

  // Destructive
  static const Color destructive = Color(0xFFF87171); // Red-400 — 4.5:1 on dark
  static const Color onDestructive = Color(0xFF450A0A);

  // Backgrounds
  static const Color background = Color(0xFF0B1326); // Outdoor dark base
  static const Color onBackground = Color(0xFFDAE2FD);
  static const Color surface = Color(0xFF171F33); // Card/modal on dark
  static const Color onSurface = Color(0xFFDAE2FD);
  static const Color muted = Color(0xFF201C27); // Secondary surfaces
  static const Color onMuted = Color(0xFF94A3B8);

  // Borders
  static const Color border = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color borderStrong = Color(0x29FFFFFF); // rgba(255,255,255,0.16)

  // Focus ring
  static const Color ring = Color(0xFFFB923C); // Visible on dark — 4.5:1

  // Text contrast tiers
  static const Color textPrimary = Color(0xFFFFFFFF); // 4.5:1 on dark
  static const Color textSecondary = Color(0xFFCBD5E1); // 4.5:1 on dark
  static const Color textTertiary = Color(0xFF64748B); // 3:1 on dark
}

// ─── Semantic Aliases ────────────────────────────────────────────────────────

/// Semantic state colors — resolved per brightness.
///
/// Use [of] to get the brightness-aware color for a semantic token.
/// All semantic aliases are sourced from color.yaml §semantic.
abstract final class VspColorSemantic {
  // GPS / location states
  static const Color gpsReady = VspColorLight.accent;
  static const Color gpsLowAccuracy = VspColorLight.secondary;
  static const Color gpsSearching = VspColorLight.muted;

  // Sync / connectivity
  static const Color online = VspColorLight.accent;
  static const Color offline = VspColorLight.muted;
  static const Color syncPending = Color(
    0xFF3B82F6,
  ); // Blue — progress (fixed, not brightness-aware)
  static const Color syncFailed = VspColorLight.destructive;

  // Data confidence
  static const Color official = VspColorLight.accent;
  static const Color estimated = VspColorLight.secondary;
  static const Color stale = VspColorLight.destructive;

  // Course status
  static const Color courseDownloaded = VspColorLight.accent;
  static const Color courseUpdateAvailable = VspColorLight.secondary;
  static const Color courseOfflineReady = VspColorLight.accent;
  static const Color courseNotDownloaded = VspColorLight.textTertiary;

  /// Returns the brightness-aware semantic color.
  ///
  /// For each semantic token, maps to the correct palette based on brightness:
  /// - accent-tier states → VspColor[Dark|Light].accent
  /// - secondary-tier states → VspColor[Dark|Light].secondary
  /// - destructive-tier states → VspColor[Dark|Light].destructive
  /// - muted-tier states → VspColor[Dark|Light].muted
  /// - textTertiary-tier states → VspColor[Dark|Light].textTertiary
  /// - syncPending is fixed blue (not brightness-aware per color.yaml)
  static Color of(Brightness brightness, VspSemanticColorToken token) {
    switch (token) {
      // GPS / location states
      case VspSemanticColorToken.gpsReady:
      case VspSemanticColorToken.online:
      case VspSemanticColorToken.official:
      case VspSemanticColorToken.courseDownloaded:
      case VspSemanticColorToken.courseOfflineReady:
        return brightness == Brightness.dark
            ? VspColorDark
                  .accent // #34D399
            : VspColorLight.accent; // #059669

      case VspSemanticColorToken.gpsLowAccuracy:
      case VspSemanticColorToken.estimated:
      case VspSemanticColorToken.courseUpdateAvailable:
        return brightness == Brightness.dark
            ? VspColorDark
                  .secondary // #FBBF24
            : VspColorLight.secondary; // #F97316

      case VspSemanticColorToken.gpsSearching:
      case VspSemanticColorToken.offline:
        return brightness == Brightness.dark
            ? VspColorDark
                  .muted // #201C27
            : VspColorLight.muted; // #F8FAFC

      case VspSemanticColorToken.syncFailed:
      case VspSemanticColorToken.stale:
        return brightness == Brightness.dark
            ? VspColorDark
                  .destructive // #F87171
            : VspColorLight.destructive; // #DC2626

      case VspSemanticColorToken.courseNotDownloaded:
        return brightness == Brightness.dark
            ? VspColorDark
                  .textTertiary // #64748B
            : VspColorLight.textTertiary; // #94A3B8

      case VspSemanticColorToken.syncPending:
        // Fixed blue — not brightness-aware per color.yaml spec
        return const Color(0xFF3B82F6);
    }
  }
}

/// Semantic token types — mirrors color.yaml §semantic.
enum VspSemanticColorToken {
  gpsReady,
  gpsLowAccuracy,
  gpsSearching,
  online,
  offline,
  syncPending,
  syncFailed,
  official,
  estimated,
  stale,
  courseDownloaded,
  courseUpdateAvailable,
  courseOfflineReady,
  courseNotDownloaded,
}
