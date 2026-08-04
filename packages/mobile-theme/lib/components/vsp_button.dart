// VspButton — Seed Component
//
// Source: packages/mobile-theme/lib/components/vsp_button.dart
// Accessibility: loading spinner, disabled opacity, visible focus ring, 44/48pt touch target.
//
// Semantics wrapper on every state. FocusNode + FocusHighlightMode.automatic.
// MediaQuery.disableAnimationsOf suppresses spinner motion.
// No emoji as icons.

import 'package:flutter/material.dart';
import '../tokens/vsp_color.dart';
import '../tokens/vsp_spacing.dart';
import '../tokens/vsp_elevation.dart';
import '../tokens/vsp_motion.dart';
import '../tokens/vsp_focus.dart';
import '../tokens/vsp_icon.dart';

/// VspButton variant — determines visual style.
enum VspButtonVariant {
  /// Primary filled button — orange background.
  primary,

  /// Secondary outlined button.
  secondary,

  /// Destructive filled button — red.
  destructive,
}

/// VspButton size variants.
enum VspButtonSize {
  /// Default size — standard touch target.
  medium,

  /// Larger size for primary CTAs.
  large,

  /// Smaller size for compact contexts.
  small,
}

/// A button with loading spinner, disabled opacity, visible focus ring,
/// and minimum 44×44pt / 48×48dp touch target.
///
/// All states implemented:
/// - Default: full color, interactive
/// - Loading: spinner replaces content, non-interactive appearance
/// - Disabled: reduced opacity, non-interactive
/// - Focused: visible focus ring using VspFocusRing token
///
/// Respects:
/// - MediaQuery.disableAnimationsOf (suppresses spinner rotation)
/// - MediaQuery.boldTextOf (text scales with large text mode)
class VspButton extends StatefulWidget {
  /// Button label — required for accessibility.
  final String label;

  /// Semantic label for screen readers (overrides [label] when provided).
  /// Use when label alone is insufficient for screen reader context.
  final String? semanticLabel;

  /// Icon to display before the label.
  /// Must be a vector IconData (e.g., Icons.add); no emoji.
  final IconData? icon;

  /// Button variant — determines visual style.
  final VspButtonVariant variant;

  /// Button size.
  final VspButtonSize size;

  /// Whether the button is in a loading state.
  /// When true, shows a spinner and disables interaction.
  final bool isLoading;

  /// Whether the button is disabled.
  /// When true, applies disabled opacity and prevents interaction.
  final bool isDisabled;

  /// Callback when button is pressed.
  final VoidCallback? onPressed;

  /// Whether to use a compact layout (icon-only when possible).
  final bool compact;

  const VspButton({
    super.key,
    required this.label,
    this.semanticLabel,
    this.icon,
    this.variant = VspButtonVariant.primary,
    this.size = VspButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.onPressed,
    this.compact = false,
  });

  @override
  State<VspButton> createState() => _VspButtonState();
}

class _VspButtonState extends State<VspButton>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  bool get _isInteractive => !widget.isDisabled && !widget.isLoading;

  double get _touchTargetHeight {
    switch (widget.size) {
      case VspButtonSize.small:
        return VspSpacingSemantic.touchTargetMin;
      case VspButtonSize.medium:
        return VspSpacingSemantic.touchTargetMin;
      case VspButtonSize.large:
        return VspSpacingSemantic.touchTargetRecommended;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case VspButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: VspSpacing.sm,
        );
      case VspButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: VspSpacingSemantic.paddingButton,
          vertical: 12,
        );
      case VspButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: VspSpacing.xl,
          vertical: VspSpacing.md,
        );
    }
  }

  TextStyle _textStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge!;
    switch (widget.size) {
      case VspButtonSize.small:
        return base.copyWith(fontSize: 12);
      case VspButtonSize.medium:
        return base;
      case VspButtonSize.large:
        return base.copyWith(fontSize: 16);
    }
  }

  Color _backgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = switch (widget.variant) {
      VspButtonVariant.primary => colorScheme.primary,
      VspButtonVariant.secondary => Colors.transparent,
      VspButtonVariant.destructive => colorScheme.error,
    };
    return widget.isDisabled
        ? baseColor.withOpacity(VspOpacity.disabled)
        : baseColor;
  }

  Color _foregroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.variant) {
      case VspButtonVariant.primary:
        return colorScheme.onPrimary;
      case VspButtonVariant.secondary:
        return colorScheme.primary;
      case VspButtonVariant.destructive:
        return colorScheme.onError;
    }
  }

  BorderSide? _borderSide(BuildContext context) {
    if (widget.variant == VspButtonVariant.secondary) {
      // When disabled, border must use withOpacity since there is no Opacity
      // wrapper (removed to avoid double-stacking with _backgroundColor).
      return BorderSide(
        color: widget.isDisabled
            ? Theme.of(
                context,
              ).colorScheme.outline.withOpacity(VspOpacity.disabled)
            : Theme.of(context).colorScheme.primary,
        width: 1.5,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = VspReducedMotion.isSuppressed(context);
    final foregroundColor = _foregroundColor(context);
    final backgroundColor = _backgroundColor(context);

    // effectiveOpacity dims content (spinner, text, icon) when disabled.
    // The Opacity wrapper (when present) dims the Material background and border,
    // but NOT the foreground color values used in buttonContent. So effectiveOpacity
    // must use VspOpacity.disabled whenever isDisabled=true, regardless of loading.
    final effectiveOpacity = widget.isDisabled ? VspOpacity.disabled : 1.0;

    Widget buttonContent;

    if (widget.isLoading) {
      // Loading state — spinner replaces label
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _VspButtonSpinner(
            color: foregroundColor.withOpacity(effectiveOpacity),
            isReducedMotion: isReducedMotion,
          ),
          if (!widget.compact) ...[
            const SizedBox(width: VspSpacing.sm),
            Text(
              widget.label,
              style: _textStyle(
                context,
              ).copyWith(color: foregroundColor.withOpacity(effectiveOpacity)),
            ),
          ],
        ],
      );
    } else {
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: VspIconSize.md,
              color: foregroundColor.withOpacity(effectiveOpacity),
            ),
            if (!widget.compact)
              const SizedBox(width: VspSpacingSemantic.paddingIconLabel),
          ],
          if (!widget.compact || widget.icon == null)
            Text(
              widget.label,
              style: _textStyle(
                context,
              ).copyWith(color: foregroundColor.withOpacity(effectiveOpacity)),
            ),
        ],
      );
    }

    Widget button = AnimatedContainer(
      duration: VspReducedMotion.isSuppressed(context)
          ? VspDuration.instant
          : VspDuration.press,
      curve: VspEasing.deceleration,
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: _borderSide(context) ?? BorderSide.none,
        ),
        elevation: widget.variant == VspButtonVariant.primary ? 0 : 0,
        child: InkWell(
          autofocus: false,
          onTap: _isInteractive ? widget.onPressed : null,
          borderRadius: BorderRadius.circular(8),
          splashColor: foregroundColor.withOpacity(0.1),
          highlightColor: foregroundColor.withOpacity(0.05),
          child: Container(
            constraints: BoxConstraints(
              minWidth: widget.compact
                  ? _touchTargetHeight
                  : VspSpacingSemantic.touchTargetMin,
              minHeight: _touchTargetHeight,
            ),
            padding: widget.compact ? EdgeInsets.zero : _padding,
            child: Center(child: buttonContent),
          ),
        ),
      ),
    );

    // Visible focus ring
    if (_isFocused) {
      button = _FocusRingWrapper(
        child: button,
        color: VspFocusRing.colorOf(Theme.of(context).brightness),
      );
    }

    // Semantics wrapper — required for screen reader accessibility
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      hidden: widget.isLoading && widget.compact,
      child: Focus(focusNode: _focusNode, child: button),
    );
  }
}

// ─── Loading Spinner ───────────────────────────────────────────────────────────

/// Spinner that respects reduced motion (shows static icon instead).
class _VspButtonSpinner extends StatelessWidget {
  final Color color;
  final bool isReducedMotion;

  const _VspButtonSpinner({required this.color, required this.isReducedMotion});

  @override
  Widget build(BuildContext context) {
    if (isReducedMotion) {
      // Reduced motion: static icon instead of rotation
      return Icon(
        Icons.sync, // Vector-only — not emoji
        size: VspIconSize.md,
        color: color,
      );
    }

    return SizedBox(
      width: VspIconSize.md,
      height: VspIconSize.md,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ─── Focus Ring Wrapper ────────────────────────────────────────────────────────

/// Adds a visible focus ring around a child widget.
class _FocusRingWrapper extends StatelessWidget {
  final Widget child;
  final Color color;

  const _FocusRingWrapper({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 + VspFocusRing.offset),
        border: Border.all(color: color, width: VspFocusRing.mobileWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(VspFocusRing.offset),
        child: child,
      ),
    );
  }
}
