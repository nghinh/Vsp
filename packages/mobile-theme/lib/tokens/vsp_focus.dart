// Design Tokens — Focus (Flutter)
//
// Source: packages/design-tokens/tokens/focus.yaml
// Platform: Flutter — Focus ring token mappings.
// Visible focus required — sourced from ux-spec §10.

import 'package:flutter/material.dart';
import 'vsp_color.dart';

/// Focus ring configuration — sourced from ux-spec §10 / focus.yaml.
abstract final class VspFocusRing {
  /// Focus ring color for light mode — meets 4.5:1 contrast on light surfaces.
  /// Uses primary ring color from color tokens.
  static const Color color = VspColorLight.ring; // #EA580C

  /// Returns the brightness-aware focus ring color.
  ///
  /// Light mode: [VspColorLight.ring] (#EA580C)
  /// Dark mode: [VspColorDark.ring] (#FB923C)
  static Color colorOf(Brightness brightness) {
    return brightness == Brightness.dark
        ? VspColorDark.ring
        : VspColorLight.ring;
  }

  /// Ring style — solid for visibility.
  static const BorderStyle style = BorderStyle.solid;

  /// Ring width — minimum 2dp for visibility.
  static const double width = 2;

  /// Ring outset from component edge (dp).
  static const double offset = 2;

  /// Platform-specific ring width.
  static const double mobileWidth = 3; // Slightly thicker for touch visibility
  static const double desktopWidth = 2;

  /// Build a focus ring InputBorder for use in OutlineInputBorder etc.
  static InputBorder buildRingBorder({Color? color}) {
    return OutlineInputBorder(
      borderSide: BorderSide(
        color: color ?? VspColorLight.ring,
        width: width,
        style: style,
      ),
      borderRadius: BorderRadius.circular(
        0,
      ), // Component radius applied separately
    );
  }
}

/// Focus highlight mode — sourced from ux-spec §10 / focus.yaml.
abstract final class VspFocusHighlight {
  /// Flutter: FocusHighlightMode.traditional — respects platform setting.
  /// When the device is using keyboard, show focus; when using touch/mouse, hide.
  /// Use with FocusHighlightModeTheme widget in the widget tree.
  static const FocusHighlightMode flutterMode = FocusHighlightMode.traditional;
}

/// Focus order rule — focus must match visual order.
abstract final class VspFocusOrder {
  /// Whether focus order matches visual DOM/widget tree order.
  static const bool matchesVisual = true;
}

/// Keyboard navigation tab index values.
abstract final class VspTabIndex {
  /// Default — focusable in natural tab order.
  static const int normal = 0;

  /// Programmatic focus only — not in tab order.
  static const int bypass = -1;
}

/// Focus visible state requirement.
abstract final class VspFocusVisible {
  /// Every interactive element must show visible focus indicator.
  static const String requirement = 'all-interactive-elements';

  /// Ring is the preferred indicator.
  static const String indicator = 'ring';

  /// Whether touch should show focus ring.
  /// False — touch is replaced by ripple effect.
  static const bool touchShowsFocus = false;

  /// Whether mouse/keyboard focus ring is suppressed.
  /// True — ring shows for keyboard, suppressed for mouse.
  static const bool keyboardSuppressMouse = true;
}
