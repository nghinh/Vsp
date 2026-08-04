// VspDistanceDisplay — Seed Component
//
// Source: packages/mobile-theme/lib/components/vsp_distance_display.dart
// Accessibility: large text support, high contrast, reduced motion.
//
// Primary on-course distance display — large monospace text optimized for
// outdoor sunlight readability. Shows front/center/back green distances.
//
// Respects:
// - MediaQuery.boldTextOf (large text mode scales up)
// - MediaQuery.disableAnimationsOf (suppresses unit toggle animation)
// - High contrast via colorScheme.onSurface on colorScheme.surface

import 'package:flutter/material.dart';
import '../tokens/vsp_typography.dart';
import '../tokens/vsp_color.dart';
import '../tokens/vsp_spacing.dart';
import '../tokens/vsp_motion.dart';
import '../tokens/vsp_icon.dart';

/// Distance unit — meters or yards.
enum DistanceUnit { meters, yards }

/// Distance position relative to the green.
enum DistancePosition {
  /// Front of green — leading edge.
  front,

  /// Center of green.
  center,

  /// Back of green — trailing edge.
  back,
}

/// Large-distance display for on-course primary distance panel.
///
/// Displays front/center/back distances in large monospace text.
/// Typography: Fira Code, very large (48px), tight leading (1.2),
/// tabular figures for numeric precision.
///
/// Large-text mode: respects MediaQuery.boldTextOf scaling.
///
/// Respects:
/// - MediaQuery.boldTextOf (large text mode scales up to 1.5x)
/// - MediaQuery.disableAnimationsOf (suppresses unit toggle animation)
/// - High contrast: onSurface on surface for maximum outdoor readability
class VspDistanceDisplay extends StatelessWidget {
  /// Front green distance (meters).
  final double? frontDistance;

  /// Center green distance (meters).
  final double? centerDistance;

  /// Back green distance (meters).
  final double? backDistance;

  /// Current unit — toggling triggers brief animation.
  final DistanceUnit unit;

  /// Current hole number.
  final int holeNumber;

  /// Par for the current hole.
  final int par;

  /// GPS accuracy state label — e.g., "GPS Ready", "Low Accuracy".
  final String? gpsStateLabel;

  /// Whether GPS accuracy is low — shows warning styling.
  final bool isGpsLowAccuracy;

  /// Callback when unit toggle is tapped.
  final VoidCallback? onUnitToggle;

  /// Callback when GPS state is tapped.
  final VoidCallback? onGpsStateTap;

  const VspDistanceDisplay({
    super.key,
    this.frontDistance,
    this.centerDistance,
    this.backDistance,
    this.unit = DistanceUnit.meters,
    required this.holeNumber,
    required this.par,
    this.gpsStateLabel,
    this.isGpsLowAccuracy = false,
    this.onUnitToggle,
    this.onGpsStateTap,
  });

  String get _unitLabel => unit == DistanceUnit.meters ? 'm' : 'yd';

  String _formatDistance(double? meters) {
    if (meters == null) return '—';
    final value = unit == DistanceUnit.meters ? meters : meters * 1.09361;
    return value.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReducedMotion = VspReducedMotion.isSuppressed(context);

    // High contrast: use textPrimary on background
    final textColor = isDark
        ? VspColorDark.textPrimary
        : VspColorLight.textPrimary;
    final mutedColor = isDark
        ? VspColorDark.textSecondary
        : VspColorLight.textSecondary;
    final warningColor = isDark
        ? VspColorDark.secondary
        : VspColorLight.secondary;

    // GPS state color
    final gpsColor = isGpsLowAccuracy
        ? warningColor
        : VspColorSemantic.gpsReady;

    return Semantics(
      label:
          'Distance display: Hole $holeNumber, Par $par. '
          'Front ${_formatDistance(frontDistance)} $_unitLabel, '
          'Center ${_formatDistance(centerDistance)} $_unitLabel, '
          'Back ${_formatDistance(backDistance)} $_unitLabel.',
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? VspColorDark.borderStrong : VspColorLight.border,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(VspSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: hole + par, GPS state, unit toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hole + Par
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hole $holeNumber',
                      style: VspTextStyles.title(context).copyWith(
                        color: textColor,
                        fontWeight: VspFontWeight.bold,
                      ),
                    ),
                    Text(
                      'Par $par',
                      style: VspTextStyles.bodySmall(
                        context,
                      ).copyWith(color: mutedColor),
                    ),
                  ],
                ),
                // GPS state
                if (gpsStateLabel != null)
                  GestureDetector(
                    onTap: onGpsStateTap,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: VspSpacingSemantic.touchTargetMin,
                        minHeight: VspSpacingSemantic.touchTargetMin,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGpsLowAccuracy
                                ? Icons.gps_not_fixed
                                : Icons.gps_fixed,
                            size: VspIconSize.sm,
                            color: gpsColor,
                          ),
                          const SizedBox(width: VspSpacing.xs),
                          Text(
                            gpsStateLabel!,
                            style: VspTextStyles.caption(
                              context,
                            ).copyWith(color: gpsColor),
                          ),
                        ],
                      ),
                    ),
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
            // Distance values row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _DistanceValue(
                  label: 'FRONT',
                  value: _formatDistance(frontDistance),
                  unit: _unitLabel,
                  textColor: mutedColor,
                  isReducedMotion: isReducedMotion,
                ),
                _DistanceValue(
                  label: 'CENTER',
                  value: _formatDistance(centerDistance),
                  unit: _unitLabel,
                  textColor: textColor,
                  isReducedMotion: isReducedMotion,
                  isPrimary: true,
                ),
                _DistanceValue(
                  label: 'BACK',
                  value: _formatDistance(backDistance),
                  unit: _unitLabel,
                  textColor: mutedColor,
                  isReducedMotion: isReducedMotion,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Individual Distance Value ─────────────────────────────────────────────────

class _DistanceValue extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color textColor;
  final bool isReducedMotion;
  final bool isPrimary;

  const _DistanceValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.textColor,
    required this.isReducedMotion,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use display style for primary (center), body for others
    final textStyle = isPrimary
        ? VspTextStyles.distanceDisplay(context)
        : VspTextStyles.heading(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: VspTextStyles.caption(context).copyWith(
            color: textColor.withOpacity(0.7),
            letterSpacing: VspLetterSpacing.widest,
          ),
        ),
        const SizedBox(height: VspSpacing.xs),
        AnimatedDefaultTextStyle(
          duration: isReducedMotion ? VspDuration.instant : VspDuration.fast,
          style: textStyle.copyWith(
            color: textColor,
            fontSize: isPrimary ? null : textStyle.fontSize,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value),
              const SizedBox(width: 2),
              Text(
                unit,
                style: textStyle.copyWith(
                  fontSize: (textStyle.fontSize ?? 48) * 0.5,
                  color: textColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Unit Toggle ──────────────────────────────────────────────────────────────

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
        child: AnimatedContainer(
          duration: isReducedMotion ? VspDuration.instant : VspDuration.press,
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
      ),
    );
  }
}
