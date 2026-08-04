// Design Tokens — Color (Flutter)
//
// Source: packages/design-tokens/tokens/color.yaml
// Platform: Flutter — Color token mappings.
//
// All values sourced from ux-spec.md §4.2.

import 'package:flutter/material.dart';

// ─── Light Mode ───────────────────────────────────────────────────────────────

/// Light mode color palette — sourced from ux-spec §4.2.
abstract final class VspColorLight {
  // Primary palette
  static const Color primary = Color(0xFFEA580C); // Orange — primary action
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(
    0xFFF97316,
  ); // Orange — secondary emphasis
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF059669); // Emerald — safe/ready/success
  static const Color onAccent = Color(0xFFFFFFFF);

  // Destructive
  static const Color destructive = Color(0xFFDC2626); // Red — danger/delete
  static const Color onDestructive = Color(0xFFFFFFFF);

  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color muted = Color(0xFFF8FAFC);
  static const Color onMuted = Color(0xFF64748B);

  // Borders
  static const Color border = Color(0x140F172A); // rgba(15,23,42,0.08)
  static const Color borderStrong = Color(0x290F172A); // rgba(15,23,42,0.16)

  // Focus ring
  static const Color ring = Color(0xFFEA580C);

  // Text contrast tiers
  static const Color textPrimary = Color(0xFF0F172A); // 4.5:1 on white
  static const Color textSecondary = Color(0xFF475569); // 4.5:1 on white
  static const Color textTertiary = Color(0xFF94A3B8); // 3:1 on white
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
