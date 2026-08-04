// Design Tokens — Icon (Flutter)
//
// Source: packages/design-tokens/tokens/icon.yaml
// Platform: Flutter — Icon token mappings.
// Vector icons only — no emoji — sourced from ux-spec §4.4.

/// Icon size scale — sourced from ux-spec §4.4.
abstract final class VspIconSize {
  static const double xs = 16; // Inline caption icons
  static const double sm = 20; // Body-small icons, list item prefix
  static const double md = 24; // Default — standard UI icons
  static const double lg = 32; // Feature icons, nav item
  static const double xl = 40; // Large illustration icons
  static const double _2xl = 48; // Empty-state illustration icons
}

/// Touch target minimums — sourced from ux-spec §4.4 / icon.yaml.
/// UX spec §4.4: icon touch area minimum 44×44pt iOS / 48×48dp Android.
abstract final class VspIconTouchTarget {
  /// iOS minimum icon touch target.
  static const double ios = 44;

  /// Android minimum icon touch target.
  static const double android = 48;

  /// Transparent padding to add to icon to achieve touch target.
  /// Formula: (touchTarget - iconSize) / 2
  ///
  /// For a status icon (size 20):
  /// iOS: (44 - 20) / 2 = 12
  /// Android: (48 - 20) / 2 = 14
  static double paddingIos(double iconSize) => (ios - iconSize) / 2;
  static double paddingAndroid(double iconSize) => (android - iconSize) / 2;
}

/// Stroke width values — sourced from ux-spec §4.4.
abstract final class VspIconStroke {
  static const double hairline = 1.0; // Fine decorative lines
  static const double thin = 1.5; // Standard outline icons
  static const double medium = 2.0; // Filled icons, medium emphasis
  static const double thick = 2.5; // Bold navigation icons
}

/// Icon tier configurations — sourced from ux-spec §4.4.
abstract final class VspIconTier {
  /// Navigation tier — bottom nav items, tab bar.
  static const double navigationSize = 24;
  static const double navigationStroke = 2.0;

  /// Action tier — buttons, toggles, form controls.
  static const double actionSize = 24;
  static const double actionStroke = 2.0;

  /// Status tier — inline status indicators, list item prefix.
  static const double statusSize = 20;
  static const double statusStroke = 1.5;

  /// Decorative tier — empty states, illustrations.
  static const double decorativeSize = 40;
  static const double decorativeStroke = 1.0;
}
