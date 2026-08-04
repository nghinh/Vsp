// Design Tokens — Elevation (Flutter)
//
// Source: packages/design-tokens/tokens/elevation.yaml
// Platform: Flutter — Elevation/shadow token mappings.
// Soft UI Evolution — sourced from ux-spec §4.1.

import 'package:flutter/material.dart';

/// Elevation shadow layers — Soft UI Evolution.
abstract final class VspElevation {
  /// Level 0 — no shadow, flat surface.
  static const BoxShadow level0 = BoxShadow(
    color: Color(0x00000000),
    offset: Offset.zero,
    blurRadius: 0,
    spreadRadius: 0,
  );

  /// Level 1 — subtle lift, cards at rest.
  /// ambient: 0 1px 2px rgba(0,0,0,0.04)
  /// directional: 0 1px 3px rgba(0,0,0,0.08)
  static const BoxShadow level1 = BoxShadow(
    color: Color(0x0A000000), // rgba(0,0,0,0.04) ≈ 0x0A
    offset: Offset(0, 1),
    blurRadius: 2,
    spreadRadius: 0,
  );

  /// Level 2 — default card elevation.
  /// ambient: 0 2px 4px rgba(0,0,0,0.06)
  /// directional: 0 2px 6px rgba(0,0,0,0.10)
  static const BoxShadow level2 = BoxShadow(
    color: Color(0x0F000000), // rgba(0,0,0,0.06) ≈ 0x0F
    offset: Offset(0, 2),
    blurRadius: 4,
    spreadRadius: 0,
  );

  /// Level 3 — raised elements, dropdowns, popovers.
  /// ambient: 0 4px 8px rgba(0,0,0,0.08)
  /// directional: 0 4px 12px rgba(0,0,0,0.12)
  static const BoxShadow level3 = BoxShadow(
    color: Color(0x14000000), // rgba(0,0,0,0.08) ≈ 0x14
    offset: Offset(0, 4),
    blurRadius: 8,
    spreadRadius: 0,
  );

  /// Level 4 — modal, dialog.
  /// ambient: 0 8px 16px rgba(0,0,0,0.10)
  /// directional: 0 8px 24px rgba(0,0,0,0.14)
  static const BoxShadow level4 = BoxShadow(
    color: Color(0x1A000000), // rgba(0,0,0,0.10) ≈ 0x1A
    offset: Offset(0, 8),
    blurRadius: 16,
    spreadRadius: 0,
  );

  /// Level 5 — full-screen overlays.
  /// ambient: 0 16px 32px rgba(0,0,0,0.12)
  /// directional: 0 16px 48px rgba(0,0,0,0.16)
  static const BoxShadow level5 = BoxShadow(
    color: Color(0x1F000000), // rgba(0,0,0,0.12) ≈ 0x1F
    offset: Offset(0, 16),
    blurRadius: 32,
    spreadRadius: 0,
  );

  /// Semantic elevation aliases for common component states.
  static const BoxShadow card = level1;
  static const BoxShadow cardHover = level2;
  static const BoxShadow cardPressed = level0;
  static const BoxShadow dropdown = level3;
  static const BoxShadow modal = level4;
  static const BoxShadow overlay = level5;
}

/// Opacity layers for disabled/muted states — sourced from ux-spec §4.1.
abstract final class VspOpacity {
  static const double fullyOpaque = 1.0;
  static const double nearOpaque = 0.95;
  static const double semiOpaque = 0.88;
  static const double disabled = 0.50; // Disabled interactive element
  static const double disabledText = 0.62; // Disabled label text
  static const double hidden = 0.00;
  static const double scrim = 0.32; // Modal backdrop scrim
  static const double scrimHeavy = 0.72; // Full-screen overlay scrim
}
