// VspIcon — Seed Component
//
// Source: packages/mobile-theme/lib/components/vsp_icon.dart
// Accessibility: vector-only enforcement, screen-reader label required.
//
// VspIcon wraps Flutter's Icon widget with design token enforcement:
// - Vector icons only (no emoji)
// - Touch target padding for 44×44pt iOS / 48×48dp Android
// - Screen reader label required for icon-only controls
//
// No emoji enforcement: this component only accepts IconData (vector).
// Using emoji as icon will cause a compile-time type error.

import 'package:flutter/material.dart';
import '../tokens/vsp_icon.dart';
import '../tokens/vsp_spacing.dart';
import '../tokens/vsp_elevation.dart';

/// VspIcon tier — determines default size and stroke weight.
enum VspIconRole {
  /// Navigation — bottom nav, tab bar. Size 24, stroke 2.0.
  navigation,

  /// Action — buttons, toggles, form controls. Size 24, stroke 2.0.
  action,

  /// Status — inline indicators, list prefix. Size 20, stroke 1.5.
  status,

  /// Decorative — empty states, illustrations. Size 40, stroke 1.0.
  decorative,
}

/// A vector icon wrapper with design token enforcement.
///
/// Enforces:
/// - Vector icons only (IconData) — no emoji (type-safe)
/// - Touch target padding for minimum 44×44pt iOS / 48×48dp Android
/// - Screen reader label required when used as icon-only control
///
/// Respects:
/// - MediaQuery.boldTextOf (icon size does not scale — icons are not text)
class VspIcon extends StatelessWidget {
  /// Icon to display — must be a vector IconData (e.g., Icons.add).
  /// Using non-IconData (e.g., emoji) will cause a compile-time error.
  final IconData icon;

  /// Semantic label — required when [asIconOnly] is true.
  /// Describes the icon's meaning to screen readers.
  final String? semanticLabel;

  /// Tier — determines default size. Default is action (24pt).
  final VspIconRole tier;

  /// Explicit icon size — overrides tier default.
  /// Must be one of VspIconSize values.
  final double? size;

  /// Color — defaults to inherit from parent.
  /// Never hardcode — always use parent text color or explicit token.
  final Color? color;

  /// Whether this icon is used as an icon-only control.
  /// When true, [semanticLabel] is required.
  final bool asIconOnly;

  /// Platform for touch target sizing.
  /// iOS: 44pt minimum. Android: 48dp minimum.
  final bool isAndroid;

  /// Whether this icon is disabled — applies reduced opacity.
  final bool isDisabled;

  const VspIcon(
    this.icon, {
    super.key,
    this.semanticLabel,
    this.tier = VspIconRole.action,
    this.size,
    this.color,
    this.asIconOnly = false,
    this.isAndroid = false,
    this.isDisabled = false,
  });

  /// Navigation tier shortcut.
  const VspIcon.navigation(
    IconData icon, {
    Key? key,
    String? semanticLabel,
    Color? color,
    bool asIconOnly = false,
    bool isAndroid = false,
    bool isDisabled = false,
  }) : this(
         key: key,
         icon,
         semanticLabel: semanticLabel,
         tier: VspIconRole.navigation,
         color: color,
         asIconOnly: asIconOnly,
         isAndroid: isAndroid,
         isDisabled: isDisabled,
       );

  /// Status tier shortcut.
  const VspIcon.status(
    IconData icon, {
    Key? key,
    String? semanticLabel,
    Color? color,
    bool asIconOnly = false,
    bool isAndroid = false,
    bool isDisabled = false,
  }) : this(
         key: key,
         icon,
         semanticLabel: semanticLabel,
         tier: VspIconRole.status,
         color: color,
         asIconOnly: asIconOnly,
         isAndroid: isAndroid,
         isDisabled: isDisabled,
       );

  double get _size {
    if (size != null) return size!;
    switch (tier) {
      case VspIconRole.navigation:
        return VspIconTier.navigationSize;
      case VspIconRole.action:
        return VspIconTier.actionSize;
      case VspIconRole.status:
        return VspIconTier.statusSize;
      case VspIconRole.decorative:
        return VspIconTier.decorativeSize;
    }
  }

  double get _touchTarget =>
      isAndroid ? VspIconTouchTarget.android : VspIconTouchTarget.ios;

  double get _touchPadding => isAndroid
      ? VspIconTouchTarget.paddingAndroid(_size)
      : VspIconTouchTarget.paddingIos(_size);

  @override
  Widget build(BuildContext context) {
    // Require semantic label for icon-only controls
    assert(
      !asIconOnly || (semanticLabel != null && semanticLabel!.isNotEmpty),
      'VspIcon: semanticLabel is required when asIconOnly is true. '
      'Icon-only controls must provide a screen reader label.',
    );

    Widget iconWidget = Icon(
      icon,
      size: _size,
      color: color, // null = inherit from parent
    );

    // Apply disabled opacity
    if (isDisabled) {
      iconWidget = Opacity(opacity: VspOpacity.disabled, child: iconWidget);
    }

    // Only add touch padding when icon is used as a touch target
    final needsTouchPadding = _touchPadding > 0;

    if (!needsTouchPadding) {
      return Semantics(label: semanticLabel, child: iconWidget);
    }

    // Add transparent padding to achieve minimum touch target
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: _size + (_touchPadding * 2),
        height: _touchTarget,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(_touchPadding),
            child: iconWidget,
          ),
        ),
      ),
    );
  }
}
