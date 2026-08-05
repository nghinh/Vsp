// Driving Zone Chart — VSP Mobile App
//
// Zone visualization chart for Driving Zone analytics screen.
// Per Story 11.2 AC1/AC3: filterable zone data with accessible chart.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/driving_zone_statistics.dart';
import 'chart_legend.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Driving zone chart showing landing zone distribution per club per hole.
///
/// Uses a grid heatmap-style visualization with accessible colors and patterns.
class DrivingZoneChart extends StatelessWidget {
  final DrivingZoneStatistics statistics;
  final int? selectedHoleNumber;

  const DrivingZoneChart({
    super.key,
    required this.statistics,
    this.selectedHoleNumber,
  });

  @override
  Widget build(BuildContext context) {
    final holeStats = selectedHoleNumber != null
        ? statistics.holeStats
              .where((h) => h.holeNumber == selectedHoleNumber)
              .toList()
        : statistics.holeStats;

    if (holeStats.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).analyticsNoZoneData));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hole selector tabs
        if (statistics.holeStats.length > 1) ...[
          _HoleSelectorTabs(
            holeStats: holeStats,
            selectedHoleNumber: selectedHoleNumber,
          ),
          const SizedBox(height: 16),
        ],
        // Zone grid visualization
        _ZoneGridView(holeStats: holeStats),
        const SizedBox(height: 16),
        // Zone legend
        _ZoneLegend(),
        const SizedBox(height: 16),
        // Dispersion summary
        _DispersionSummary(statistics: statistics),
      ],
    );
  }
}

class _HoleSelectorTabs extends StatelessWidget {
  final List<HoleZoneStats> holeStats;
  final int? selectedHoleNumber;

  const _HoleSelectorTabs({required this.holeStats, this.selectedHoleNumber});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: holeStats.map((h) {
          final isSelected = selectedHoleNumber == h.holeNumber;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(AppLocalizations.of(context).analyticsHoleLabel('${h.holeNumber}')),
              selected: isSelected,
              onSelected: (_) {},
              avatar: CircleAvatar(
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                radius: 10,
                child: Text(
                  '${h.holeNumber}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ZoneGridView extends StatelessWidget {
  final List<HoleZoneStats> holeStats;

  const _ZoneGridView({required this.holeStats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: holeStats.map((hole) => _HoleZoneCard(hole: hole)).toList(),
    );
  }
}

class _HoleZoneCard extends StatelessWidget {
  final HoleZoneStats hole;

  const _HoleZoneCard({required this.hole});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Hole ${hole.holeNumber}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                if (hole.clubName != null)
                  Chip(
                    label: Text(hole.clubName!),
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                Text(
                  '${hole.totalShots} shots',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Zone heatmap grid
            SizedBox(
              height: 120,
              child: _ZoneGrid(
                zoneCells: hole.zoneCells,
                totalShots: hole.totalShots,
              ),
            ),
            const SizedBox(height: 8),
            // Average distance
            if (hole.averageDistanceYards != null)
              Text(
                'Avg distance: ${hole.averageDistanceYards!.toStringAsFixed(1)} yds',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoneGrid extends StatelessWidget {
  final List<ZoneCell> zoneCells;
  final int totalShots;

  _ZoneGrid({required this.zoneCells, required this.totalShots});

  @override
  Widget build(BuildContext context) {
    // Build a 3x3 grid (horizontal: left/center/right, distance: short/mid/long)
    return Column(
      children: [
        // Column headers
        Row(
          children: [
            SizedBox(width: 40),
            Expanded(
              child: Center(
                child: Text(AppLocalizations.of(context).analyticsShort, style: TextStyle(fontSize: 10)),
              ),
            ),
            Expanded(
              child: Center(child: Text(AppLocalizations.of(context).analyticsMid, style: TextStyle(fontSize: 10))),
            ),
            Expanded(
              child: Center(
                child: Text(AppLocalizations.of(context).analyticsLong, style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ),
        // Grid rows: Left, Center, Right
        ...[-1, 0, 1].map((hz) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    _horizontalLabel(hz),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                ...[0, 1, 2].map((db) {
                  final cell = _findCell(hz, db);
                  final pct = cell?.percentage ?? 0.0;
                  final count = cell?.shotCount ?? 0;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _heatmapColor(pct),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      height: 30,
                      child: Center(
                        child: Text(
                          count > 0 ? '${pct.toStringAsFixed(0)}%' : '-',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: pct > 50 ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }),
      ],
    );
  }

  ZoneCell? _findCell(int horizontalZone, int distanceBand) {
    try {
      return zoneCells.firstWhere(
        (c) =>
            c.horizontalZone == horizontalZone &&
            c.distanceBand == distanceBand,
      );
    } catch (_) {
      return null;
    }
  }

  String _horizontalLabel(int hz) {
    switch (hz) {
      case -1:
        return 'Left';
      case 0:
        return 'Center';
      case 1:
        return 'Right';
      default:
        return '';
    }
  }

  Color _heatmapColor(double percentage) {
    // Accessible heatmap: blue (cold) → yellow → red (hot)
    if (percentage <= 0) return Colors.grey.shade200;
    if (percentage < 20) return const Color(0xFFBBDEFB); // Light blue
    if (percentage < 40) return const Color(0xFF64B5F6); // Medium blue
    if (percentage < 60) return const Color(0xFFFFEB3B); // Yellow
    if (percentage < 80) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }
}

class _ZoneLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChartLegend(
      items: const [
        LegendItem(
          label: '< 20%',
          color: Color(0xFFBBDEFB),
          patternName: 'low',
        ),
        LegendItem(
          label: '20-40%',
          color: Color(0xFF64B5F6),
          patternName: 'med_low',
        ),
        LegendItem(
          label: '40-60%',
          color: Color(0xFFFFEB3B),
          patternName: 'medium',
        ),
        LegendItem(
          label: '60-80%',
          color: Color(0xFFFF9800),
          patternName: 'med_high',
        ),
        LegendItem(
          label: '> 80%',
          color: Color(0xFFF44336),
          patternName: 'high',
        ),
      ],
    );
  }
}

class _DispersionSummary extends StatelessWidget {
  final DrivingZoneStatistics statistics;

  const _DispersionSummary({required this.statistics});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryChip(
          icon: Icons.golf_course,
          label: AppLocalizations.of(context).analyticsTotalShots,
          value: '${statistics.totalShots}',
        ),
        const SizedBox(width: 12),
        _SummaryChip(
          icon: Icons.scatter_plot,
          label: AppLocalizations.of(context).analyticsAvgDispersion,
          value: statistics.averageDispersion.toStringAsFixed(2),
        ),
        const SizedBox(width: 12),
        _SummaryChip(
          icon: Icons.category,
          label: AppLocalizations.of(context).analyticsClubs,
          value: '${statistics.clubIds.length}',
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
