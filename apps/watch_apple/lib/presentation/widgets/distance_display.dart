// Distance Display — VSP Watch Apple App
//
// Renders the primary glanceable distance panel (FCB + pin).
// AC-1, AC-2, AC-3: hole/par/score, front-center-back, pin/hazard.
//
// Story 10.1 — Slice 2: Watch UI Shell & Navigation

import 'package:flutter/material.dart';
import '../../domain/watch_distance_data.dart';
import '../theme/watch_theme.dart';

/// Distance display mode (meters or yards).
enum DistanceUnit { meters, yards }

/// Primary glanceable distance panel showing front-center-back distances.
///
/// Renders three distance values in a horizontal row with labels.
/// Optionally shows pin distance below.
class DistanceDisplay extends StatelessWidget {
  /// Distance data to display.
  final WatchDistanceData distanceData;

  /// Use yards instead of meters.
  final DistanceUnit unit;

  /// Show pin distance below the FCB row.
  final bool showPin;

  /// Show confidence indicator.
  final bool showConfidence;

  const DistanceDisplay({
    super.key,
    required this.distanceData,
    this.unit = DistanceUnit.meters,
    this.showPin = true,
    this.showConfidence = true,
  });

  bool get _useYards => unit == DistanceUnit.yards;

  String _formatDistance(double meters) {
    final value = _useYards ? meters * 1.09361 : meters;
    final unitLabel = _useYards ? 'yd' : 'm';
    return '${value.round()} $unitLabel';
  }

  @override
  Widget build(BuildContext context) {
    final fcb = distanceData.fcb;

    return Semantics(
      label: 'Distance to hole: front ${_formatDistance(fcb[0].meters)}, '
          'center ${_formatDistance(fcb[1].meters)}, '
          'back ${_formatDistance(fcb[2].meters)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FCB Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _DistanceColumn(
                label: 'FRONT',
                distance: fcb[0].meters,
                formatted: _formatDistance(fcb[0].meters),
                color: WatchColors.distanceFront,
                confidence: fcb[0].confidence,
              ),
              _DistanceColumn(
                label: 'CENTER',
                distance: fcb[1].meters,
                formatted: _formatDistance(fcb[1].meters),
                color: WatchColors.distanceCenter,
                confidence: fcb[1].confidence,
                isPrimary: true,
              ),
              _DistanceColumn(
                label: 'BACK',
                distance: fcb[2].meters,
                formatted: _formatDistance(fcb[2].meters),
                color: WatchColors.distanceBack,
                confidence: fcb[2].confidence,
              ),
            ],
          ),

          // Pin distance (optional)
          if (showPin && distanceData.pin != null) ...[
            const SizedBox(height: WatchSpacing.distanceDisplayGap),
            _PinDistance(
              pin: distanceData.pin!,
              formatted: _formatDistance(distanceData.pin!.meters),
            ),
          ],

          // Confidence indicator (optional)
          if (showConfidence && distanceData.hasAccuracyWarning) ...[
            const SizedBox(height: WatchSpacing.tightGap),
            _AccuracyWarning(
              accuracyMeters: distanceData.gpsAccuracyMeters,
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual distance column (label + value).
class _DistanceColumn extends StatelessWidget {
  final String label;
  final double distance;
  final String formatted;
  final Color color;
  final double confidence;
  final bool isPrimary;

  const _DistanceColumn({
    required this.label,
    required this.distance,
    required this.formatted,
    required this.color,
    required this.confidence,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $formatted',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: WatchTypography.distanceLabel.copyWith(
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatted,
            style: isPrimary
                ? WatchTypography.distanceLarge
                : WatchTypography.distanceMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Pin/target distance display.
class _PinDistance extends StatelessWidget {
  final WatchDistance pin;
  final String formatted;

  const _PinDistance({
    required this.pin,
    required this.formatted,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pin distance: $formatted',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: WatchColors.pinHighlight.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: WatchColors.pinHighlight.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 14,
              color: WatchColors.pinHighlight,
            ),
            const SizedBox(width: 4),
            Text(
              'PIN $formatted',
              style: WatchTypography.distanceSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// GPS accuracy warning indicator.
class _AccuracyWarning extends StatelessWidget {
  final double accuracyMeters;

  const _AccuracyWarning({
    required this.accuracyMeters,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'GPS accuracy warning: ${accuracyMeters.toStringAsFixed(0)} meters',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: WatchColors.warning.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber,
              size: 10,
              color: WatchColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              '${accuracyMeters.toStringAsFixed(0)}m GPS',
              style: WatchTypography.caption.copyWith(
                color: WatchColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hazard distance list for watch display.
class HazardDistanceList extends StatelessWidget {
  final List<WatchHazardDistance> hazards;
  final bool useYards;

  const HazardDistanceList({
    super.key,
    required this.hazards,
    this.useYards = false,
  });

  String _formatDistance(double meters) {
    final value = useYards ? meters * 1.09361 : meters;
    final unitLabel = useYards ? 'yd' : 'm';
    return '${value.round()} $unitLabel';
  }

  IconData _hazardIcon(String type) {
    switch (type) {
      case 'bunker':
        return Icons.landscape;
      case 'water':
        return Icons.water;
      case 'ob':
        return Icons.flag;
      case 'penalty':
        return Icons.warning;
      default:
        return Icons.circle;
    }
  }

  Color _hazardColor(String type) {
    switch (type) {
      case 'bunker':
        return const Color(0xFFE8C96A);
      case 'water':
        return const Color(0xFF5AC8FA);
      case 'ob':
        return WatchColors.error;
      case 'penalty':
        return WatchColors.warning;
      default:
        return WatchColors.onBackgroundSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hazards.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: '${hazards.length} hazards nearby',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hazards.take(3).map((hazard) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hazardIcon(hazard.type),
                  size: 12,
                  color: _hazardColor(hazard.type),
                ),
                const SizedBox(width: 4),
                Text(
                  hazard.label,
                  style: WatchTypography.caption.copyWith(
                    color: _hazardColor(hazard.type),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDistance(hazard.meters),
                  style: WatchTypography.badge.copyWith(
                    color: _hazardColor(hazard.type),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
