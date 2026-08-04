// Hazard Distance List — VSP Mobile App
//
// Story 6.4 — Wave 3: UI Components
// UX spec §6.3: Hazard UX — grouped hazard rows with icon, name, near/far/carry
// UX spec §10: Accessibility — each row has semantic label, scrollable
//
// Scrollable list of hazard distances grouped by hazard type.
// Each row shows: icon, name, near distance, far/carry distance.

import 'package:flutter/material.dart';

import '../../../application/distance/distance_state.dart';
import '../../../domain/models/hazard_geometry.dart';
import '../../../domain/value_objects/distance_measurement.dart';
import '../../../domain/value_objects/distance_type.dart';
import '../../../features/profile/data/profile_dto.dart' show DistanceUnit;
import 'distance_value_display.dart';

/// Hazard distance list widget.
///
/// Scrollable list of hazards on the current hole.
/// Each hazard row shows:
/// - Hazard type icon (bunker/water/OB)
/// - Hazard name
/// - Near distance
/// - Far distance or carry distance (if applicable)
///
/// Groups hazards by type (bunker, water, OB) and sorts within groups.
/// Accessible: each row has a full semantics label.
class HazardDistanceList extends StatelessWidget {
  /// The current distance state.
  final DistanceState state;

  /// Callback when a hazard row is tapped (shows detail dialog).
  final void Function(HazardGeometry hazard)? onHazardTap;

  const HazardDistanceList({super.key, required this.state, this.onHazardTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useYards = state.selectedUnit == DistanceUnit.yards;

    if (!state.hasHazardDistances) {
      return const SizedBox.shrink();
    }

    // Build list of hazard rows
    final rows = _buildRows(context, useYards);

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'HAZARDS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 1.0,
            ),
          ),
        ),

        // Scrollable hazard list
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
            itemBuilder: (_, index) => rows[index],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRows(BuildContext context, bool useYards) {
    final rows = <Widget>[];
    final hazardDistances = state.hazardDistances;

    // Group by type and build rows
    for (final entry in hazardDistances.entries) {
      final hazardId = entry.key;
      final distances = entry.value;

      // Get the hazard geometry from the hole
      final hazard = _findHazard(hazardId);
      if (hazard == null) continue;

      rows.add(
        _HazardRow(
          hazard: hazard,
          distances: distances,
          useYards: useYards,
          onTap: onHazardTap != null ? () => onHazardTap!(hazard) : null,
        ),
      );
    }

    return rows;
  }

  HazardGeometry? _findHazard(String hazardId) {
    final hole = state.holeGeometry;
    if (hole == null) return null;
    return hole.hazards.where((h) => h.id == hazardId).firstOrNull;
  }
}

class _HazardRow extends StatelessWidget {
  final HazardGeometry hazard;
  final Map<DistanceType, DistanceMeasurement> distances;
  final bool useYards;
  final VoidCallback? onTap;

  const _HazardRow({
    required this.hazard,
    required this.distances,
    required this.useYards,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final nearDist = _nearDistance();
    final farDist = _farDistance();
    final carryDist = _carryDistance();

    final semanticsLabel =
        '${hazard.name}: '
        'near ${_fmt(nearDist)}, '
        '${farDist != null ? 'far ${_fmt(farDist)}' : ''} '
        '${carryDist != null ? 'carry ${_fmt(carryDist)}' : ''}';

    return Semantics(
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Hazard type icon
              _HazardIcon(hazard: hazard),
              const SizedBox(width: 10),

              // Hazard name
              Expanded(
                flex: 2,
                child: Text(
                  hazard.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Near distance
              Expanded(
                flex: 2,
                child: _DistanceChip(
                  label: 'Near',
                  measurement: nearDist,
                  useYards: useYards,
                ),
              ),

              const SizedBox(width: 6),

              // Far or Carry distance
              Expanded(
                flex: 2,
                child: carryDist != null
                    ? _DistanceChip(
                        label: 'Carry',
                        measurement: carryDist,
                        useYards: useYards,
                        isCarry: true,
                      )
                    : farDist != null
                    ? _DistanceChip(
                        label: 'Far',
                        measurement: farDist,
                        useYards: useYards,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DistanceMeasurement? _nearDistance() {
    switch (hazard.type) {
      case HazardType.bunker:
        return distances[DistanceType.bunkerNear];
      case HazardType.water:
      case HazardType.penaltyArea:
        return distances[DistanceType.waterNear];
      case HazardType.ob:
        return distances[DistanceType.ob];
    }
  }

  DistanceMeasurement? _farDistance() {
    switch (hazard.type) {
      case HazardType.bunker:
        return distances[DistanceType.bunkerFar];
      case HazardType.water:
      case HazardType.penaltyArea:
        return distances[DistanceType.waterFar];
      case HazardType.ob:
        return null; // OB only has near, not far
    }
  }

  DistanceMeasurement? _carryDistance() {
    switch (hazard.type) {
      case HazardType.bunker:
        return distances[DistanceType.bunkerCarry];
      case HazardType.water:
      case HazardType.penaltyArea:
        return distances[DistanceType.waterCarry];
      case HazardType.ob:
        return null;
    }
  }

  String _fmt(DistanceMeasurement? m) {
    if (m == null) return '--';
    return m.format(useYards: useYards);
  }
}

class _HazardIcon extends StatelessWidget {
  final HazardGeometry hazard;

  const _HazardIcon({required this.hazard});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _buildParts();

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  (IconData, Color) _buildParts() {
    switch (hazard.type) {
      case HazardType.bunker:
        return (Icons.landscape, const Color(0xFFD4A017)); // amber/sand
      case HazardType.water:
      case HazardType.penaltyArea:
        return (Icons.water_drop, const Color(0xFF2563EB)); // blue
      case HazardType.ob:
        return (Icons.block, const Color(0xFFDC2626)); // red
    }
  }
}

class _DistanceChip extends StatelessWidget {
  final String label;
  final DistanceMeasurement? measurement;
  final bool useYards;
  final bool isCarry;

  const _DistanceChip({
    required this.label,
    required this.measurement,
    required this.useYards,
    this.isCarry = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final value =
        measurement?.displayValue(useYards: useYards).round().toString() ??
        '--';
    final unit = measurement?.unitLabel(useYards: useYards) ?? '';
    final chipColor = isCarry ? const Color(0xFFF97316) : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: chipColor.withOpacity(0.8),
              letterSpacing: 0.3,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: chipColor,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 1),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: chipColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
