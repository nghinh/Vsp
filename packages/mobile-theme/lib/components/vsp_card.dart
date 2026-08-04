// VspCard — Seed Component
//
// Source: packages/mobile-theme/lib/components/vsp_card.dart
// Accessibility: elevation tokens, state color surface support.
//
// Card with semantic elevation, subtle border, and state-aware surface color.
// Supports GPS/sync/data-confidence state tinting from VspColorSemantic.

import 'package:flutter/material.dart';
import '../tokens/vsp_color.dart';
import '../tokens/vsp_spacing.dart';
import '../tokens/vsp_elevation.dart';
import 'vsp_loading_indicator.dart';

/// VspCard elevation level — maps to elevation token levels.
enum VspCardElevation {
  /// Flat surface — level0.
  flat,

  /// Subtle lift, cards at rest — level1.
  resting,

  /// Default raised — level2.
  raised,

  /// Dropdown/popover — level3.
  elevated,
}

/// State tint for VspCard — applies semantic state color overlay.
enum VspCardState {
  /// Default card — no state tint.
  none,

  /// GPS ready / online / official / downloaded.
  ready,

  /// GPS low accuracy / estimated / update available.
  warning,

  /// GPS unavailable / sync failed / stale / destructive.
  alert,

  /// Sync pending / downloading / loading.
  loading,
}

/// A card with elevation tokens and optional state color surface.
///
/// Uses elevation.shadow.* tokens for shadow levels.
/// Optional state tint overlays a semantic state color as a subtle surface tint.
/// Border uses subtle border token from color tokens.
///
/// Respects:
/// - MediaQuery.boldTextOf for large-text scaling within card content
class VspCard extends StatelessWidget {
  /// Card content — typically a Column or ListTile.
  final Widget child;

  /// Elevation level — determines shadow depth.
  final VspCardElevation elevation;

  /// Optional state tint — applies semantic state color as surface overlay.
  final VspCardState state;

  /// Callback when card is tapped.
  final VoidCallback? onTap;

  /// Whether the card is disabled — applies reduced opacity.
  final bool isDisabled;

  /// Optional semantic label for screen readers.
  final String? semanticLabel;

  /// Border radius — defaults to 12dp (matches spacing.card.paddingCard).
  final double borderRadius;

  /// Whether to show a loading indicator in the card.
  /// When true, a VspLoadingIndicator is rendered centered in the card.
  final bool isLoading;

  const VspCard({
    super.key,
    required this.child,
    this.elevation = VspCardElevation.resting,
    this.state = VspCardState.none,
    this.onTap,
    this.isDisabled = false,
    this.semanticLabel,
    this.borderRadius = 12,
    this.isLoading = false,
  });

  BoxShadow _resolveShadow() {
    switch (elevation) {
      case VspCardElevation.flat:
        return VspElevation.level0;
      case VspCardElevation.resting:
        return VspElevation.level1;
      case VspCardElevation.raised:
        return VspElevation.level2;
      case VspCardElevation.elevated:
        return VspElevation.level3;
    }
  }

  Color _resolveStateColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (state) {
      case VspCardState.none:
        return Colors.transparent;
      case VspCardState.ready:
        // Subtle green tint
        return VspColorSemantic.gpsReady.withOpacity(0.06);
      case VspCardState.warning:
        // Subtle amber tint
        return VspColorSemantic.gpsLowAccuracy.withOpacity(0.06);
      case VspCardState.alert:
        // Subtle red tint
        return VspColorSemantic.stale.withOpacity(0.06);
      case VspCardState.loading:
        // Subtle blue tint
        return VspColorSemantic.syncPending.withOpacity(0.06);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadow = _resolveShadow();
    final stateColor = _resolveStateColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Surface color: default surface + optional state tint
    final surfaceColor = Color.alphaBlend(stateColor, colorScheme.surface);

    // Border: subtle border token, slightly stronger on dark surfaces
    final borderColor = isDark
        ? VspColorDark.borderStrong
        : VspColorLight.border;

    Widget card = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [if (shadow != VspElevation.level0) shadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: isLoading
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(VspSpacingSemantic.paddingCard),
                  child: VspLoadingIndicator(semanticLabel: 'Loading'),
                ),
              )
            : InkWell(
                onTap: isDisabled ? null : onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: colorScheme.primary.withOpacity(0.05),
                highlightColor: colorScheme.primary.withOpacity(0.03),
                child: Padding(
                  padding: const EdgeInsets.all(VspSpacingSemantic.paddingCard),
                  child: child,
                ),
              ),
      ),
    );

    if (isDisabled) {
      card = Opacity(opacity: VspOpacity.disabled, child: card);
    }

    // Semantics wrapper
    return Semantics(
      container: true,
      label: semanticLabel,
      enabled: !isDisabled,
      button: onTap != null,
      child: card,
    );
  }
}
