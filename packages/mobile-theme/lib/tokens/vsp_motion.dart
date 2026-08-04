// Design Tokens — Motion (Flutter)
//
// Source: packages/design-tokens/tokens/motion.yaml
// Platform: Flutter — Motion/animation token mappings.
// Motion tier: subtle — sourced from ux-spec §11.

import 'package:flutter/material.dart';

/// Duration values — sourced from ux-spec §11.
abstract final class VspDuration {
  /// Instant — no perceptible animation.
  static const Duration instant = Duration.zero;

  /// Fast — pressed feedback (80–150ms per UX spec).
  static const Duration press = Duration(milliseconds: 80);

  /// Maximum for pressed feedback.
  static const Duration pressMax = Duration(milliseconds: 150);

  /// Standard — screen transitions, state changes (150–300ms per UX spec).
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);

  /// Maximum recommended for non-critical UI.
  static const Duration slow = Duration(milliseconds: 300);

  /// Deliberate — non-critical reveals only.
  static const Duration reveal = Duration(milliseconds: 400);

  /// Absolute maximum — avoid exceeding.
  static const Duration max = Duration(milliseconds: 500);
}

/// Easing curves — sourced from ux-spec §11.
abstract final class VspEasing {
  /// Standard material easing — deceleration.
  static const Curve standard = Curves.easeOut;

  /// Element appears — enter.
  static const Curve deceleration = Curves.easeOut;

  /// Element disappears — exit.
  static const Curve acceleration = Curves.easeIn;

  /// Spring / bounce (use sparingly).
  static const Curve spring = Curves.elasticOut;

  /// Overshoot.
  static const Curve overshoot = Curves.easeOutBack;

  /// Linear — use only for opacity fade (never for movement).
  static const Curve linear = Curves.linear;
}

/// Motion type definitions combining duration and easing.
abstract final class VspMotionType {
  /// Press feedback — immediate tap confirmation.
  static const Duration press = VspDuration.press;
  static const Curve pressEasing = VspEasing.deceleration;

  /// State changes, panel slides, tab switches.
  static const Duration transition = VspDuration.normal;
  static const Curve transitionEasing = VspEasing.standard;

  /// New content appearing (list items, modals).
  static const Duration reveal = VspDuration.slow;
  static const Curve revealEasing = VspEasing.deceleration;

  /// Loading skeleton shimmer.
  static const Duration skeleton = VspDuration.reveal;
  static const Curve skeletonEasing = VspEasing.linear;

  /// Indeterminate spinner — one full rotation per iteration.
  static const Duration spinner = VspDuration.instant;
  static const Curve spinnerEasing = VspEasing.linear;

  /// Full page enter.
  static const Duration pageTransition = VspDuration.slow;
  static const Curve pageTransitionEasing = VspEasing.deceleration;
}

/// Reduced motion overrides — sourced from ux-spec §11.
/// When user enables reduced motion, suppress all motion.
abstract final class VspReducedMotion {
  /// All durations collapse to instant.
  static const Duration press = VspDuration.instant;
  static const Duration transition = VspDuration.instant;
  static const Duration reveal = VspDuration.instant;
  static const Duration skeleton = VspDuration.instant;
  static const Duration spinner = VspDuration.instant;
  static const Duration pageTransition = VspDuration.instant;

  /// All easing collapses to linear.
  static const Curve easing = VspEasing.linear;

  /// Whether animations are suppressed based on MediaQuery.
  static bool isSuppressed(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  /// Resolve press duration respecting reduced motion.
  static Duration resolvePress(BuildContext context) {
    return isSuppressed(context) ? press : VspMotionType.press;
  }

  /// Resolve transition duration respecting reduced motion.
  static Duration resolveTransition(BuildContext context) {
    return isSuppressed(context) ? transition : VspMotionType.transition;
  }

  /// Resolve reveal duration respecting reduced motion.
  static Duration resolveReveal(BuildContext context) {
    return isSuppressed(context) ? reveal : VspMotionType.reveal;
  }
}
