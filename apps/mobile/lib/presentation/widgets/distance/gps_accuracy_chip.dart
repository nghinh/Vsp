// GPS Accuracy Chip — VSP Mobile App
//
// Story 6.4 — Wave 3: UI Components
// UX spec §6.1: GPS accuracy state visible on distance panel
// UX spec §4.2: GPS color coding — green (<5m), amber (5-10m), red (>10m)
//
// Displays GPS accuracy as a semantic chip with color and value label.
// Reuses the GpsAccuracyLevel from DistanceMeasurement.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

import '../../../domain/value_objects/distance_measurement.dart';

/// GPS accuracy display chip.
///
/// Shows current GPS accuracy with semantic color coding:
/// - < 5m: excellent — green
/// - 5–10m: good — green/amber
/// - 10–20m: moderate — amber
/// - >= 20m: poor — red
///
/// Includes the numeric accuracy value in the label.
/// Follows UX spec §4.2: color + label (not color-only).
class GpsAccuracyChip extends StatelessWidget {
  /// The GPS accuracy level to display.
  final GpsAccuracyLevel? level;

  /// The numeric accuracy in meters (optional — shown in label).
  final double? accuracyMeters;

  /// Callback when the chip is tapped (shows detail dialog).
  final VoidCallback? onTap;

  const GpsAccuracyChip({
    super.key,
    this.level,
    this.accuracyMeters,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLevel = level ?? GpsAccuracyLevel.poor;
    final (label, color, icon) = _buildParts(
      AppLocalizations.of(context),
      effectiveLevel,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            if (accuracyMeters != null) ...[
              const SizedBox(width: 4),
              Text(
                '±${accuracyMeters!.round()}m',
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String label, Color color, IconData icon) _buildParts(
    AppLocalizations l10n,
    GpsAccuracyLevel lvl,
  ) {
    switch (lvl) {
      case GpsAccuracyLevel.excellent:
        return (l10n.gpsReady, _greenColor, Icons.gps_fixed);
      case GpsAccuracyLevel.good:
        return (l10n.gpsGood, _greenColor, Icons.gps_fixed);
      case GpsAccuracyLevel.moderate:
        return (l10n.gpsFair, _amberColor, Icons.gps_not_fixed);
      case GpsAccuracyLevel.poor:
        return (l10n.gpsPoor, _redColor, Icons.gps_off);
    }
  }

  static const _greenColor = Color(0xFF059669);
  static const _amberColor = Color(0xFFF97316);
  static const _redColor = Color(0xFFDC2626);
}
