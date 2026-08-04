// VspLoadingIndicator — Seed Component
//
// Source: packages/mobile-theme/lib/components/vsp_loading_indicator.dart
// Accessibility: subtle motion, reduced-motion suppressed.
//
// Loading indicator that respects MediaQuery.disableAnimationsOf.
// When reduced motion is enabled, shows a static icon instead of rotation.

import 'package:flutter/material.dart';
import '../tokens/vsp_motion.dart';
import '../tokens/vsp_icon.dart';

/// VspLoadingIndicator size variants.
enum VspLoadingIndicatorSize {
  /// Small — for inline use. 16×16pt.
  xs,

  /// Small — for list items. 20×20pt.
  sm,

  /// Default — standard use. 24×24pt.
  md,

  /// Large — for empty states. 32×32pt.
  lg,

  /// Extra large — for full-page loading. 48×48pt.
  xl,
}

/// A loading indicator with subtle motion, respecting reduced motion.
///
/// When reduced motion is enabled (MediaQuery.disableAnimationsOf):
/// - Spinner rotation is replaced with a static sync icon
/// - All opacity transitions are instant
///
/// Motion tokens used:
/// - duration.spinner: infinite rotation (when not suppressed)
/// - easing.spinner: linear
class VspLoadingIndicator extends StatelessWidget {
  /// Indicator size. Default is md (24pt).
  final VspLoadingIndicatorSize size;

  /// Color — inherits from parent by default.
  final Color? color;

  /// Optional semantic label for screen readers.
  final String? semanticLabel;

  /// Whether to show a label alongside the indicator.
  final String? label;

  const VspLoadingIndicator({
    super.key,
    this.size = VspLoadingIndicatorSize.md,
    this.color,
    this.semanticLabel,
    this.label,
  });

  double get _size {
    switch (size) {
      case VspLoadingIndicatorSize.xs:
        return 16;
      case VspLoadingIndicatorSize.sm:
        return 20;
      case VspLoadingIndicatorSize.md:
        return 24;
      case VspLoadingIndicatorSize.lg:
        return 32;
      case VspLoadingIndicatorSize.xl:
        return 48;
    }
  }

  double get _strokeWidth {
    switch (size) {
      case VspLoadingIndicatorSize.xs:
        return 1.5;
      case VspLoadingIndicatorSize.sm:
        return 1.5;
      case VspLoadingIndicatorSize.md:
        return 2.0;
      case VspLoadingIndicatorSize.lg:
        return 2.5;
      case VspLoadingIndicatorSize.xl:
        return 3.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = VspReducedMotion.isSuppressed(context);
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    Widget indicator;

    if (isReducedMotion) {
      // Reduced motion: static icon instead of rotation
      // Use Icons.sync as the static representation of "loading/syncing"
      // This is vector-only — no emoji.
      indicator = Icon(Icons.sync, size: _size, color: effectiveColor);
    } else {
      // Normal motion: spinning indicator
      indicator = SizedBox(
        width: _size,
        height: _size,
        child: CircularProgressIndicator(
          strokeWidth: _strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
        ),
      );
    }

    // Optional label next to indicator
    if (label != null) {
      return Semantics(
        label: semanticLabel ?? 'Loading: $label',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            const SizedBox(width: 8),
            Text(
              label!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: effectiveColor),
            ),
          ],
        ),
      );
    }

    return Semantics(label: semanticLabel ?? 'Loading', child: indicator);
  }
}

/// A skeleton shimmer loading placeholder.
///
/// Shows a subtle shimmer animation that is suppressed when
/// reduced motion is enabled (shows static placeholder instead).
///
/// Respects:
/// - MediaQuery.disableAnimationsOf (suppresses shimmer)
class VspSkeleton extends StatefulWidget {
  /// Skeleton width — double.infinity for full-width placeholder.
  final double? width;

  /// Skeleton height.
  final double height;

  /// Border radius.
  final double borderRadius;

  /// Base color — defaults to surfaceVariant.
  final Color? color;

  const VspSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 4,
    this.color,
  });

  @override
  State<VspSkeleton> createState() => _VspSkeletonState();
}

class _VspSkeletonState extends State<VspSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VspMotionType.skeleton,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: VspEasing.linear));
    // Only start animation if reduced motion is NOT suppressed
    // The actual suppression check happens in build()
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = VspReducedMotion.isSuppressed(context);
    final baseColor =
        widget.color ?? Theme.of(context).colorScheme.surfaceContainerHighest;

    // Shimmer gradient colors
    final highlightColor = baseColor.withOpacity(0.6);

    Widget skeleton = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: isReducedMotion ? baseColor : null,
      ),
    );

    if (!isReducedMotion) {
      // Only animate when reduced motion is NOT suppressed
      if (!_controller.isAnimating) {
        _controller.repeat();
      }

      skeleton = AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  (_animation.value - 1).clamp(0.0, 1.0),
                  _animation.value.clamp(0.0, 1.0),
                  (_animation.value + 1).clamp(0.0, 1.0),
                ],
                colors: [baseColor, highlightColor, baseColor],
              ),
            ),
          );
        },
      );
    }

    return Semantics(label: 'Loading placeholder', child: skeleton);
  }
}
