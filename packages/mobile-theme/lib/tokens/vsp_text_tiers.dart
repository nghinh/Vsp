// The three text tiers, as something a widget can read from the theme.
//
// `ColorScheme` has one text colour per surface — `onSurface` — and this
// design has three: the number a golfer reads at a glance, the label beside
// it, and the unit or the caveat under it. So the tiers lived in
// `VspColorDark.textPrimary` and friends, and 42 widgets named the dark class
// directly to get at them.
//
// A widget that names `VspColorDark` is a widget that renders dark whatever
// theme it is in, which is the whole reason the app could not have a light
// mode: flipping `themeMode` would have turned the surfaces light and left
// this text unchanged — near-white on near-white.
//
// The tiers are not invented here. They are the same token values, moved
// somewhere brightness can reach them.

import 'package:flutter/material.dart';

import 'vsp_color.dart';

/// Text colours for the three levels of emphasis this design uses.
@immutable
class VspTextTiers extends ThemeExtension<VspTextTiers> {
  const VspTextTiers({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  /// What the golfer came to read: the distance, the score, the hole number.
  final Color primary;

  /// The label that says what the number is.
  final Color secondary;

  /// Units, timestamps, hints — present, and never competing with the number.
  ///
  /// Deliberately the lowest contrast of the three, which is why it is a tier
  /// and not a shade: anything that must be read outdoors does not belong
  /// here.
  final Color tertiary;

  static const VspTextTiers light = VspTextTiers(
    primary: VspColorLight.textPrimary,
    secondary: VspColorLight.textSecondary,
    tertiary: VspColorLight.textTertiary,
  );

  static const VspTextTiers dark = VspTextTiers(
    primary: VspColorDark.textPrimary,
    secondary: VspColorDark.textSecondary,
    tertiary: VspColorDark.textTertiary,
  );

  /// The tiers in force, or the dark set where no theme carries them.
  ///
  /// The fallback is dark because that is what every one of these widgets
  /// rendered before this existed — a widget lifted into a bare `MaterialApp`
  /// in a test keeps the colours it had rather than turning invisible.
  static VspTextTiers of(BuildContext context) =>
      Theme.of(context).extension<VspTextTiers>() ?? dark;

  @override
  VspTextTiers copyWith({Color? primary, Color? secondary, Color? tertiary}) {
    return VspTextTiers(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
    );
  }

  @override
  VspTextTiers lerp(ThemeExtension<VspTextTiers>? other, double t) {
    if (other is! VspTextTiers) return this;
    return VspTextTiers(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
    );
  }
}
