// Target Card Widget — VSP Mobile App
//
// Displays ball-to-target and target-to-pin distances in Fira Code monospace.
// Shows unit toggle, GPS accuracy state, and tap-to-replace behavior.
//
// Accessibility:
// - Screen reader labels on all distance values
// - Non-color-only accuracy display (icon + text)
// - 44pt minimum touch targets
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart' hide DistanceUnit;

import '../domain/target_model.dart';
import 'target_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Card widget showing ball-to-target and target-to-pin distances.
///
/// Typography: Fira Code monospace, large numbers, tabular figures.
/// Color: primary orange for target distances, semantic colors for accuracy.
///
/// Respects:
/// - MediaQuery.boldTextOf (large text mode scales up)
/// - MediaQuery.disableAnimationsOf (suppresses unit toggle animation)
/// - High contrast via colorScheme.onSurface on colorScheme.surface
class TargetCard extends StatelessWidget {
  /// The current target (used for accuracy display).
  final TargetModel? target;

  /// Computed distances.
  final TargetDistances? distances;

  /// Current unit — toggling converts and animates.
  final DistanceUnit unit;

  /// Callback when unit toggle is tapped.
  final VoidCallback? onUnitToggle;

  /// Callback when card is tapped (replace target).
  final VoidCallback? onTap;

  const TargetCard({
    super.key,
    this.target,
    this.distances,
    this.unit = DistanceUnit.meters,
    this.onUnitToggle,
    this.onTap,
  });

  String get _unitLabel => unit == DistanceUnit.meters ? 'm' : 'yd';

  String _formatDistance(double? meters) {
    if (meters == null || distances == null) return '—';
    final value = unit == DistanceUnit.meters ? meters : meters * 1.09361;
    return value.round().toString();
  }

  Color _accuracyColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (target == null) {
      return isDark ? VspColorDark.textTertiary : VspColorLight.textTertiary;
    }
    switch (target!.accuracy) {
      case GpsAccuracy.high:
        return VspColorSemantic.of(
          Theme.of(context).brightness,
          VspSemanticColorToken.gpsReady,
        );
      case GpsAccuracy.medium:
        return VspColorSemantic.of(
          Theme.of(context).brightness,
          VspSemanticColorToken.gpsLowAccuracy,
        );
      case GpsAccuracy.low:
      case GpsAccuracy.unknown:
        return VspColorSemantic.of(
          Theme.of(context).brightness,
          VspSemanticColorToken.stale,
        );
    }
  }

  String _accuracyLabel(GpsAccuracy accuracy) {
    switch (accuracy) {
      case GpsAccuracy.high:
        return 'High';
      case GpsAccuracy.medium:
        return 'Medium';
      case GpsAccuracy.low:
        return 'Low';
      case GpsAccuracy.unknown:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReducedMotion = MediaQuery.of(context).disableAnimations;

    final textColor = isDark
        ? VspColorDark.textPrimary
        : VspColorLight.textPrimary;
    final mutedColor = isDark
        ? VspColorDark.textSecondary
        : VspColorLight.textSecondary;
    final primaryColor = isDark ? VspColorDark.primary : VspColorLight.primary;

    final accuracyColor = _accuracyColor(context);

    return Semantics(
      label: _buildSemanticsLabel(),
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? VspColorDark.borderStrong : VspColorLight.border,
              width: 1,
            ),
            boxShadow: const [VspElevation.level1],
          ),
          padding: const EdgeInsets.all(VspSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Target label + accuracy + unit toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.my_location,
                        size: VspIconSize.sm,
                        color: primaryColor,
                      ),
                      const SizedBox(width: VspSpacing.xs),
                      Text(
                        'TARGET',
                        style: VspTextStyles.label(context).copyWith(
                          color: primaryColor,
                          letterSpacing: VspLetterSpacing.widest,
                        ),
                      ),
                    ],
                  ),
                  // Accuracy indicator
                  if (target != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          target!.accuracy == GpsAccuracy.high
                              ? Icons.gps_fixed
                              : Icons.gps_not_fixed,
                          size: VspIconSize.xs,
                          color: accuracyColor,
                        ),
                        const SizedBox(width: VspSpacing.half),
                        Text(
                          _accuracyLabel(target!.accuracy),
                          style: VspTextStyles.caption(
                            context,
                          ).copyWith(color: accuracyColor),
                        ),
                      ],
                    ),
                  // Unit toggle
                  _UnitToggle(
                    unit: unit,
                    onTap: onUnitToggle,
                    isReducedMotion: isReducedMotion,
                  ),
                ],
              ),
              const SizedBox(height: VspSpacing.md),
              // Distance values
              Row(
                children: [
                  Expanded(
                    child: _DistanceColumn(
                      label: AppLocalizations.of(context).targetBallToTarget,
                      value: _formatDistance(distances?.ballToTargetMeters),
                      unit: _unitLabel,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDark ? VspColorDark.border : VspColorLight.border,
                  ),
                  Expanded(
                    child: _DistanceColumn(
                      label: AppLocalizations.of(context).targetToPin,
                      value: _formatDistance(distances?.targetToPinMeters),
                      unit: _unitLabel,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSemanticsLabel() {
    if (target == null || distances == null) {
      return 'Target card. Tap map to place target.';
    }
    final bt = _formatDistance(distances!.ballToTargetMeters);
    final tp = _formatDistance(distances!.targetToPinMeters);
    return 'Target distances. Ball to target $bt $_unitLabel. Target to pin $tp $_unitLabel. Tap to replace target.';
  }
}

// ─── Individual Distance Column ─────────────────────────────────────────────────

class _DistanceColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color textColor;
  final Color mutedColor;
  final bool isPrimary;

  const _DistanceColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.textColor,
    required this.mutedColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isPrimary
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VspTextStyles.caption(context).copyWith(
            color: mutedColor.withOpacity(0.7),
            letterSpacing: VspLetterSpacing.wider,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: VspSpacing.half),
        Row(
          mainAxisSize: isPrimary ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: isPrimary
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: VspTextStyles.mono(context).copyWith(
                color: textColor,
                fontSize: isPrimary ? 24 : 20,
                fontWeight: isPrimary
                    ? VspFontWeight.bold
                    : VspFontWeight.medium,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: VspTextStyles.caption(
                context,
              ).copyWith(color: mutedColor, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Unit Toggle ───────────────────────────────────────────────────────────────

class _UnitToggle extends StatelessWidget {
  final DistanceUnit unit;
  final VoidCallback? onTap;
  final bool isReducedMotion;

  const _UnitToggle({
    required this.unit,
    this.onTap,
    required this.isReducedMotion,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: VspSpacingSemantic.touchTargetMin,
          minHeight: VspSpacingSemantic.touchTargetMin,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: VspSpacing.sm,
          vertical: VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          unit == DistanceUnit.meters ? 'm' : 'yd',
          style: VspTextStyles.label(
            context,
          ).copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
