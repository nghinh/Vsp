// Design Tokens — Spacing (Flutter)
//
// Source: packages/design-tokens/tokens/spacing.yaml
// Platform: Flutter — Spacing token mappings.
// All values in dp (device-independent pixels / points).

/// Spacing scale — 4/8dp rhythm — sourced from ux-spec §4.5.
abstract final class VspSpacing {
  // Base unit = 4dp
  static const double unit = 4;
  static const double quad = 8; // 2× base unit, primary rhythm

  // Micro gaps
  static const double _0 = 0;
  static const double _0_5 = 2; // half-unit — tight internal padding
  static const double _1 = 4; // 1 unit
  static const double _1_5 = 6; // 1.5 units — between icon and label
  static const double _2 = 8; // 2 units — quad

  // Standard gaps
  static const double _3 = 12; // 3 units
  static const double _4 = 16; // 4 units — mobile page gutter minimum
  static const double _5 = 20; // 5 units
  static const double _6 = 24; // 6 units
  static const double _8 = 32; // 8 units — large section gap
  static const double _10 = 40; // 10 units
  static const double _12 = 48; // 12 units — max comfortable touch separation
  static const double _16 = 64; // 16 units — generous section padding
  static const double _20 = 80; // 20 units — page-level padding on tablet
  static const double _24 = 96; // 24 units
  static const double _32 = 128; // 32 units — max spacing

  // Aliases for readability
  static const double none = _0;
  static const double half = _0_5;
  static const double xs = _1;
  static const double sm = _2;
  static const double md = _4;
  static const double lg = _6;
  static const double xl = _8;
  static const double xxl = _12;
}

/// Semantic spacing aliases — sourced from ux-spec §4.5 / spacing.yaml.
abstract final class VspSpacingSemantic {
  // Touch targets
  /// iOS minimum touch target (44pt).
  static const double touchTargetMin = 44;

  /// Android minimum touch target (48dp).
  static const double touchTargetMinAndroid = 48;

  /// Recommended touch target for primary actions.
  static const double touchTargetRecommended = 48;

  // Gutters
  /// Mobile page gutters minimum — UX spec §4.5.
  static const double gutterMobile = 16;
  static const double gutterTablet = 24;
  static const double gutterDesktop = 32;

  // Safe area
  static const double safeAreaTop = 44; // Status bar
  static const double safeAreaBottom = 34; // Home indicator
  static const double safeAreaHorizontal = 16;

  // Component internal padding
  static const double paddingIconLabel =
      6; // Gap between icon and text in buttons
  static const double paddingCard = 16;
  static const double paddingCardDense = 12;
  static const double paddingInput = 12;
  static const double paddingButton = 16;

  // Stack gaps
  static const double gapStack = 8; // Vertical stack between list items
  static const double gapStackDense = 4; // Dense list (portal tables)
  static const double gapSection = 24; // Section separator

  // Navigation
  static const double bottomNavHeight = 64;
  static const double bottomNavSafeArea = 34;

  // Focus ring
  static const double focusRingOutset = 2; // Outset from component edge
}
