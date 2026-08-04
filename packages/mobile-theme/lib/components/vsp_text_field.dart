// VspTextField — Seed Component
//
// Source: packages/mobile-theme/lib/components/vsp_text_field.dart
// Accessibility: error state, helper/copy, 44pt touch target, focus ring.
//
// TextField with error state, helper text, and accessible focus behavior.
// Uses VspFocusRing for visible focus. Respects MediaQuery.disableAnimationsOf.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/vsp_spacing.dart';
import '../tokens/vsp_elevation.dart';
import '../tokens/vsp_focus.dart';
import '../tokens/vsp_motion.dart';

/// VspTextField variant — determines keyboard type and input format.
enum VspTextFieldVariant {
  /// Standard text input.
  text,

  /// Numeric input — numeric keyboard on mobile.
  numeric,

  /// Decimal numeric input.
  decimal,

  /// Email input — email keyboard.
  email,

  /// Phone input — phone keyboard.
  phone,
}

/// A text field with error state, helper text, and accessible focus behavior.
///
/// States:
/// - Default: standard appearance
/// - Error: red border + error message visible
/// - Disabled: reduced opacity, non-interactive
/// - Focused: visible focus ring using VspFocusRing token
///
/// Respects:
/// - MediaQuery.disableAnimationsOf (suppresses focus ring animation)
/// - MediaQuery.boldTextOf (helper/error text scales)
/// - 44pt minimum touch target height
class VspTextField extends StatefulWidget {
  /// Label — always visible (not placeholder-only per UX spec §8.1).
  final String label;

  /// Placeholder text shown when empty.
  final String? placeholder;

  /// Helper text shown below input — explains format/consequence.
  final String? helperText;

  /// Error message — shown when [hasError] is true.
  final String? errorText;

  /// Whether the field has an error — shows error border + errorText.
  final bool hasError;

  /// Whether the field is disabled.
  final bool isDisabled;

  /// Initial value for uncontrolled usage.
  final String? initialValue;

  /// Controller for controlled usage.
  final TextEditingController? controller;

  /// Callback when value changes.
  final ValueChanged<String>? onChanged;

  /// Callback when submitted.
  final ValueChanged<String>? onSubmitted;

  /// Text field variant — determines keyboard type.
  final VspTextFieldVariant variant;

  /// Whether to autofocus this field.
  final bool autofocus;

  /// Number of lines — default 1 (single line).
  final int maxLines;

  /// Maximum character length.
  final int? maxLength;

  /// Whether to obscure text (for passwords).
  final bool obscureText;

  /// FocusNode for external focus management.
  final FocusNode? focusNode;

  /// Semantic label for screen readers (overrides label when provided).
  final String? semanticLabel;

  const VspTextField({
    super.key,
    required this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.hasError = false,
    this.isDisabled = false,
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.variant = VspTextFieldVariant.text,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.focusNode,
    this.semanticLabel,
  });

  @override
  State<VspTextField> createState() => _VspTextFieldState();
}

class _VspTextFieldState extends State<VspTextField> {
  TextEditingController? _internalController;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _internalController = widget.controller == null
        ? TextEditingController(text: widget.initialValue)
        : null;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _internalController?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  TextInputType get _keyboardType {
    switch (widget.variant) {
      case VspTextFieldVariant.text:
        return TextInputType.text;
      case VspTextFieldVariant.numeric:
        return TextInputType.number;
      case VspTextFieldVariant.decimal:
        return const TextInputType.numberWithOptions(decimal: true);
      case VspTextFieldVariant.email:
        return TextInputType.emailAddress;
      case VspTextFieldVariant.phone:
        return TextInputType.phone;
    }
  }

  TextInputAction get _textInputAction {
    if (widget.maxLines == 1) {
      return widget.variant == VspTextFieldVariant.numeric
          ? TextInputAction.done
          : TextInputAction.next;
    }
    return TextInputAction.newline;
  }

  List<TextInputFormatter>? get _inputFormatters {
    switch (widget.variant) {
      case VspTextFieldVariant.numeric:
        return [FilteringTextInputFormatter.digitsOnly];
      case VspTextFieldVariant.decimal:
        return [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReducedMotion = VspReducedMotion.isSuppressed(context);

    final effectiveBorderColor = widget.hasError
        ? colorScheme.error
        : _isFocused
        ? colorScheme.primary
        : colorScheme.outline;

    final effectiveBorderWidth = _isFocused || widget.hasError
        ? VspFocusRing.width
        : 1.0;

    // Build helper/error text
    final helperContent = widget.hasError && widget.errorText != null
        ? Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          )
        : widget.helperText != null
        ? Text(
            widget.helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        : null;

    Widget textField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label — always visible per UX spec §8.1
        Text(
          widget.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: widget.hasError ? colorScheme.error : colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: VspSpacing.xs),
        // Input field
        AnimatedContainer(
          duration: isReducedMotion ? VspDuration.instant : VspDuration.fast,
          curve: VspEasing.standard,
          constraints: const BoxConstraints(
            minHeight: VspSpacingSemantic.touchTargetMin,
          ),
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? colorScheme.surfaceContainerHighest.withOpacity(
                    VspOpacity.disabled,
                  )
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: effectiveBorderColor.withOpacity(
                widget.isDisabled ? VspOpacity.disabled : 1.0,
              ),
              width: effectiveBorderWidth,
            ),
          ),
          child: TextField(
            controller: widget.controller ?? _internalController,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            keyboardType: _keyboardType,
            textInputAction: _textInputAction,
            inputFormatters: _inputFormatters,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            obscureText: widget.obscureText,
            enabled: !widget.isDisabled,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: widget.isDisabled
                  ? colorScheme.onSurface.withOpacity(VspOpacity.disabledText)
                  : colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: VspSpacingSemantic.paddingInput,
                vertical: 12,
              ),
              counterText: '',
            ),
          ),
        ),
        // Helper or error text
        if (helperContent != null) ...[
          const SizedBox(height: VspSpacing.xs),
          helperContent,
        ],
      ],
    );

    // Focus ring overlay when focused
    if (_isFocused && !widget.isDisabled) {
      textField = _FocusRingOverlay(
        color: widget.hasError ? colorScheme.error : colorScheme.primary,
        borderRadius: 8,
        child: textField,
      );
    }

    // Disabled opacity
    if (widget.isDisabled) {
      textField = Opacity(opacity: VspOpacity.disabled, child: textField);
    }

    // Semantics wrapper
    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      textField: true,
      enabled: !widget.isDisabled,
      hidden: false,
      child: textField,
    );
  }
}

// ─── Focus Ring Overlay ────────────────────────────────────────────────────────

/// Adds a visible focus ring around a child using a Stack overlay.
class _FocusRingOverlay extends StatelessWidget {
  final Widget child;
  final Color color;
  final double borderRadius;

  const _FocusRingOverlay({
    required this.child,
    required this.color,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: VspReducedMotion.isSuppressed(context)
          ? VspDuration.instant
          : VspDuration.fast,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius + VspFocusRing.offset),
        border: Border.all(color: color, width: VspFocusRing.width),
      ),
      padding: const EdgeInsets.all(VspFocusRing.offset),
      child: child,
    );
  }
}
