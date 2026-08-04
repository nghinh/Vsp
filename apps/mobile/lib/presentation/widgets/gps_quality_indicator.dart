// GPS Quality Indicator — VSP Mobile App
//
// Story 6.1: Acquire and Qualify Location
// AC2: Accuracy above 10m or stale positions trigger warning state.
//
// Displays GPS quality as a semantic chip: "GPS Ready", "Low Accuracy", "Stale", "Unavailable".
// Follows UX spec §4.2 state colors:
// - GPS ready: accent green
// - GPS low accuracy: amber/orange warning
// - GPS stale: red/gray with explicit label
// - GPS unavailable: red/gray with explicit label

import 'package:flutter/material.dart';

import '../../../domain/models/location_quality.dart';
import '../../../domain/models/qualified_location.dart';
import 'package:mobile_theme/mobile_theme.dart' as theme;

enum _GpsQuality { ready, lowAccuracy, stale, unavailable }

/// GPS quality indicator chip.
///
/// Shows current GPS quality state with semantic color and label.
/// Used in the hole map header (per UX spec §8.2).
class GpsQualityIndicator extends StatelessWidget {
  /// The current location quality.
  final LocationQuality quality;

  /// The current qualified location (used for accuracy display).
  final QualifiedLocation? location;

  /// Callback when the indicator is tapped (shows detail dialog).
  final VoidCallback? onTap;

  const GpsQualityIndicator({
    super.key,
    required this.quality,
    this.location,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _buildParts();
    final colorScheme = Theme.of(context).colorScheme;

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
            if (location != null &&
                location!.accuracyMeters != null &&
                quality == _gpsQualityFromQuality(quality)) ...[
              const SizedBox(width: 4),
              Text(
                '±${location!.accuracyMeters!.round()}m',
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String label, Color color, IconData icon) _buildParts() {
    switch (quality) {
      case LocationQuality.ready:
        return ('GPS Ready', _greenColor, Icons.gps_fixed);
      case LocationQuality.lowAccuracy:
        return ('Low Accuracy', _amberColor, Icons.gps_not_fixed);
      case LocationQuality.stale:
        return ('GPS Stale', _redColor, Icons.gps_off);
      case LocationQuality.unavailable:
        return ('No GPS', _redColor, Icons.location_disabled);
    }
  }

  static const _greenColor = Color(0xFF059669);
  static const _amberColor = Color(0xFFF97316);
  static const _redColor = Color(0xFFDC2626);

  _GpsQuality _gpsQualityFromQuality(LocationQuality q) {
    switch (q) {
      case LocationQuality.ready:
        return _GpsQuality.ready;
      case LocationQuality.lowAccuracy:
        return _GpsQuality.lowAccuracy;
      case LocationQuality.stale:
        return _GpsQuality.stale;
      case LocationQuality.unavailable:
        return _GpsQuality.unavailable;
    }
  }
}

/// GPS quality detail dialog shown when indicator is tapped.
class GpsQualityDetailDialog extends StatelessWidget {
  final QualifiedLocation location;

  const GpsQualityDetailDialog({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final warning = location.hasWarning
        ? LocationWarning.fromQualifiedLocation(location)
        : null;

    return AlertDialog(
      title: const Text('GPS Quality'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('Quality', location.accuracyLabel),
          _DetailRow(
            'Accuracy',
            '±${location.accuracyMeters?.round() ?? '?'}m',
          ),
          _DetailRow('Source', location.source.name.toUpperCase()),
          if (location.heading != null)
            _DetailRow('Heading', '${location.heading!.round()}°'),
          _DetailRow(
            'Age',
            location.ageSeconds >= 0 ? '${location.ageSeconds}s' : 'Unknown',
          ),
          if (warning != null) ...[
            const Divider(),
            Text(
              warning.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _colorForQuality(warning.quality),
              ),
            ),
            const SizedBox(height: 4),
            Text(warning.message),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Color _colorForQuality(LocationQuality q) {
    switch (q) {
      case LocationQuality.ready:
        return _greenColor;
      case LocationQuality.lowAccuracy:
        return _amberColor;
      case LocationQuality.stale:
      case LocationQuality.unavailable:
        return _redColor;
    }
  }

  static const _greenColor = Color(0xFF059669);
  static const _amberColor = Color(0xFFF97316);
  static const _redColor = Color(0xFFDC2626);
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
