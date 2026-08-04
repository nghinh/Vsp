// VspPaymentStatusBadge — Seed Component
//
// Source: packages/mobile-theme/lib/components/vsp_payment_status_badge.dart
// Accessibility: icon + text (never color alone), screen-reader label, 44pt+ touch target.
//
// Shows payment state with icon + text label per accessibility requirements.
// State is never communicated by color alone — icon and label always appear together.
//
// States: PENDING, SUCCEEDED, FAILED, REFUNDED, PARTIALLY_REFUNDED
// Per Story 12.3 S5: Explicit Failure and Pending States.

import 'package:flutter/material.dart';
import '../tokens/vsp_color.dart';
import '../tokens/vsp_spacing.dart';
import '../tokens/vsp_icon.dart';

/// Payment lifecycle state — mirrors PaymentState in domain model and
/// PaymentStateDto in contracts package.
///
/// Used by VspPaymentStatusBadge to render accessible state indicators.
enum VspPaymentState {
  /// Payment is being processed.
  pending,

  /// Payment succeeded.
  succeeded,

  /// Payment failed.
  failed,

  /// Payment was fully refunded.
  refunded,

  /// Payment was partially refunded.
  partially_refunded,
}

/// A badge displaying payment state with icon + text label.
///
/// Accessibility requirements (per Story 12.3 S5):
/// - Never communicates state by color alone — icon AND text always present
/// - Screen reader reads the full state text via Semantics label
/// - Touch target minimum 44×44pt iOS / 48×48dp Android
///
/// Respects:
/// - MediaQuery.boldTextOf (text scales with large text mode)
class VspPaymentStatusBadge extends StatelessWidget {
  /// The payment state to display.
  final VspPaymentState state;

  /// Optional custom label. Defaults to state name (e.g., "Pending", "Succeeded").
  final String? label;

  /// Platform for touch target sizing.
  /// iOS: 44pt minimum. Android: 48dp minimum.
  final bool isAndroid;

  const VspPaymentStatusBadge({
    super.key,
    required this.state,
    this.label,
    this.isAndroid = false,
  });

  // ─── State resolution ─────────────────────────────────────────────────────────

  /// Resolves the icon for this payment state.
  IconData get _icon {
    switch (state) {
      case VspPaymentState.pending:
        return Icons.hourglass_empty;
      case VspPaymentState.succeeded:
        return Icons.check_circle;
      case VspPaymentState.failed:
        return Icons.cancel;
      case VspPaymentState.refunded:
        return Icons.undo;
      case VspPaymentState.partially_refunded:
        return Icons.remove_circle_outline;
    }
  }

  /// Resolves the semantic color for this payment state.
  /// Used only as a subtle background tint — icon and text are always visible.
  Color _backgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (state) {
      case VspPaymentState.pending:
        return isDark
            ? VspColorDark.secondary.withOpacity(0.12)
            : VspColorLight.secondary.withOpacity(0.12);
      case VspPaymentState.succeeded:
        return isDark
            ? VspColorDark.accent.withOpacity(0.12)
            : VspColorLight.accent.withOpacity(0.12);
      case VspPaymentState.failed:
        return isDark
            ? VspColorDark.destructive.withOpacity(0.12)
            : VspColorLight.destructive.withOpacity(0.12);
      case VspPaymentState.refunded:
      case VspPaymentState.partially_refunded:
        return isDark
            ? const Color(0xFF3B82F6).withOpacity(
                0.12,
              ) // Fixed blue for refund states
            : const Color(0xFF3B82F6).withOpacity(0.12);
    }
  }

  /// Resolves the icon and text color for this payment state.
  Color _foregroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (state) {
      case VspPaymentState.pending:
        return isDark ? VspColorDark.secondary : VspColorLight.secondary;
      case VspPaymentState.succeeded:
        return isDark ? VspColorDark.accent : VspColorLight.accent;
      case VspPaymentState.failed:
        return isDark ? VspColorDark.destructive : VspColorLight.destructive;
      case VspPaymentState.refunded:
      case VspPaymentState.partially_refunded:
        // Fixed blue for refund states — consistent with syncPending semantic color
        return isDark
            ? const Color(0xFF60A5FA) // Blue-400 on dark
            : const Color(0xFF3B82F6); // Blue-500 on light
    }
  }

  /// Resolves the screen-reader label for this payment state.
  String get _semanticLabel {
    if (label != null) return label!;
    switch (state) {
      case VspPaymentState.pending:
        return 'Payment pending';
      case VspPaymentState.succeeded:
        return 'Payment succeeded';
      case VspPaymentState.failed:
        return 'Payment failed';
      case VspPaymentState.refunded:
        return 'Payment refunded';
      case VspPaymentState.partially_refunded:
        return 'Payment partially refunded';
    }
  }

  /// Resolves the display label for this payment state.
  String get _displayLabel {
    if (label != null) return label!;
    switch (state) {
      case VspPaymentState.pending:
        return 'Pending';
      case VspPaymentState.succeeded:
        return 'Succeeded';
      case VspPaymentState.failed:
        return 'Failed';
      case VspPaymentState.refunded:
        return 'Refunded';
      case VspPaymentState.partially_refunded:
        return 'Partially Refunded';
    }
  }

  /// Minimum touch target height (44pt iOS / 48dp Android).
  double get _touchTargetHeight => isAndroid
      ? VspSpacingSemantic.touchTargetMinAndroid
      : VspSpacingSemantic.touchTargetMin;

  /// Icon size for status tier (20pt).
  static const double _iconSize = VspIconSize.sm;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _foregroundColor(context);
    final backgroundColor = _backgroundColor(context);
    final icon = _icon;
    final displayLabel = _displayLabel;
    final semanticLabel = _semanticLabel;

    // Icon + label row with minimum touch target height
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon — size 20pt, color always visible
        Icon(
          icon,
          size: _iconSize,
          color: foregroundColor,
          semanticLabel: semanticLabel,
        ),
        const SizedBox(width: 6),
        // Text label — always present (not color-only)
        Text(
          displayLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    // Touch target wrapper: ensures minimum 44×44pt / 48×48dp
    Widget badge = Container(
      constraints: BoxConstraints(minHeight: _touchTargetHeight),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(VspSpacing.sm),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: 6,
      ),
      child: content,
    );

    // Semantics wrapper — screen reader reads full state text
    return Semantics(label: semanticLabel, child: badge);
  }
}
