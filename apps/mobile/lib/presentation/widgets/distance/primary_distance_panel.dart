// Primary Distance Panel — VSP Mobile App
//
// Story 6.4 — Wave 3: UI Components
// UX spec §6.1: Primary distance panel — front/center/back green always visible
// UX spec §6.1: GPS accuracy state visible, unit toggle m/yd, confidence + source + timestamp
// UX spec §6.1: Stale/low-accuracy → warning state, not hidden distances
// UX spec §10: Accessibility — semantics, non-color-only, 44pt touch targets
//
// The primary glanceable distance panel shown on the active round map.
// Always displays front/center/back green distances prominently.

import 'package:flutter/material.dart';

import '../../../application/distance/distance_state.dart';
import '../../../domain/value_objects/distance_measurement.dart';
import '../../../domain/value_objects/distance_type.dart';
import '../../../features/profile/data/profile_dto.dart' show DistanceUnit;
import 'distance_value_display.dart';
import 'gps_accuracy_chip.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Primary distance panel widget.
///
/// Always visible during active round — shows front/center/back green
/// distances in large typography. Includes GPS accuracy, unit toggle,
/// and confidence indicators.
///
/// Wraps [DistanceValueDisplay] for each distance type.
/// Accessibly exposes all values via [Semantics] labels.
class PrimaryDistancePanel extends StatelessWidget {
  /// The current distance state.
  final DistanceState state;

  /// Callback when the unit toggle is tapped.
  final VoidCallback? onUnitToggle;

  /// Callback when the GPS accuracy chip is tapped (shows detail dialog).
  final VoidCallback? onAccuracyTap;

  const PrimaryDistancePanel({
    super.key,
    required this.state,
    this.onUnitToggle,
    this.onAccuracyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useYards = state.selectedUnit == DistanceUnit.yards;

    return Semantics(
      label: AppLocalizations.of(context).primaryDistanceSemantics(
        _fmt(state.frontGreen, useYards),
        _fmt(state.centerGreen, useYards),
        _fmt(state.backGreen, useYards),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: GPS accuracy + unit toggle
            _buildHeaderRow(context, colorScheme),

            const SizedBox(height: 8),

            // Distances row: front / center / back
            _buildDistancesRow(context, useYards),

            const SizedBox(height: 4),

            // Timestamp (relative) + confidence summary
            _buildFooterRow(context, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        // GPS accuracy chip
        GpsAccuracyChip(
          level: state.accuracyLevel,
          accuracyMeters: state.gpsAccuracyMeters,
          onTap: onAccuracyTap,
        ),

        const Spacer(),

        // Unit toggle button — minimum 44pt touch target
        Semantics(
          label: AppLocalizations.of(
            context,
          ).distanceToggleUnit(state.selectedUnit.value),
          button: true,
          child: GestureDetector(
            onTap: onUnitToggle,
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                state.selectedUnit == DistanceUnit.meters ? 'm' : 'yd',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistancesRow(BuildContext context, bool useYards) {
    final front = state.frontGreen;
    final center = state.centerGreen;
    final back = state.backGreen;

    // If GPS is unavailable, show last known or placeholder
    if (!state.hasGps) {
      return _NoDataRow(
        message: AppLocalizations.of(context).distanceWaitingGps,
      );
    }

    if (state.status == DistanceStatus.noHoleGeometry) {
      return _NoDataRow(
        message: AppLocalizations.of(context).distanceNoHoleData,
      );
    }

    // A distance the app does not have is shown as unknown, not as a number.
    //
    // All three used to fall back to `_placeholderMeasurement`, which was zero
    // metres carrying `DistanceSource.official` — so a hole with no green
    // geometry rendered "0 m" under an Official badge. On the one screen a
    // golfer reads before choosing a club, that is the worst possible way to
    // be wrong: it is not a missing answer, it is a confident false one.
    if (front == null && center == null && back == null) {
      return _NoDataRow(
        message: AppLocalizations.of(context).distanceNoHoleData,
      );
    }

    return Row(
      children: [
        Expanded(
          child: _DistanceCell(
            cellKey: const ValueKey('front'),
            measurement: front,
            useYards: useYards,
            label: AppLocalizations.of(context).distanceFront,
          ),
        ),
        _VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(
          child: _DistanceCell(
            cellKey: const ValueKey('center'),
            measurement: center,
            useYards: useYards,
            label: AppLocalizations.of(context).distanceCenter,
          ),
        ),
        _VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(
          child: _DistanceCell(
            cellKey: const ValueKey('back'),
            measurement: back,
            useYards: useYards,
            label: AppLocalizations.of(context).distanceBack,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterRow(BuildContext context, ColorScheme colorScheme) {
    final timestamp = state.timestamp;
    final confLevel = state.confidenceLevel;

    String timeLabel = '';
    if (timestamp != null) {
      final age = DateTime.now().difference(timestamp);
      if (age.inSeconds < 60) {
        timeLabel = '${age.inSeconds}s ago';
      } else {
        timeLabel = '${age.inMinutes}m ago';
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (timestamp != null)
          Text(
            AppLocalizations.of(context).distanceUpdatedAt(timeLabel),
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          )
        else
          const SizedBox.shrink(),

        if (confLevel != null) _ConfidenceLabel(level: confLevel),
      ],
    );
  }

  String _fmt(DistanceMeasurement? m, bool useYards) {
    if (m == null) return '--';
    return m.format(useYards: useYards);
  }
}

/// One of the three green distances, or an em dash where there is no distance.
class _DistanceCell extends StatelessWidget {
  final Key cellKey;
  final DistanceMeasurement? measurement;
  final bool useYards;
  final String label;

  const _DistanceCell({
    required this.cellKey,
    required this.measurement,
    required this.useYards,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final value = measurement;
    if (value != null) {
      return DistanceValueDisplay(
        key: cellKey,
        measurement: value,
        useYards: useYards,
        label: label,
        excludeFromSemantics: false,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      key: cellKey,
      label: AppLocalizations.of(context).distanceUnavailableSemantics(label),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '—',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDataRow extends StatelessWidget {
  final String message;

  const _NoDataRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final Color color;

  const _VerticalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 60, color: color.withOpacity(0.3));
  }
}

class _ConfidenceLabel extends StatelessWidget {
  final ConfidenceLevel level;

  const _ConfidenceLabel({required this.level});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _parts(level);

    return Semantics(
      label: AppLocalizations.of(context).distanceConfidenceDetail(label),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$label confidence',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static (Color, String) _parts(ConfidenceLevel lvl) {
    switch (lvl) {
      case ConfidenceLevel.high:
        return (const Color(0xFF059669), 'High');
      case ConfidenceLevel.medium:
        return (const Color(0xFFF97316), 'Medium');
      case ConfidenceLevel.low:
        return (const Color(0xFFEA580C), 'Low');
      case ConfidenceLevel.veryLow:
        return (const Color(0xFFDC2626), 'Very low');
    }
  }
}
