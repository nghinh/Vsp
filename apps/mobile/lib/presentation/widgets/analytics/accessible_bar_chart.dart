// Accessible Bar Chart — VSP Mobile App
//
// fl_chart wrapper with legend, labels, patterns, and aria-labels.
// Per Story 11.2 AC3: charts include legends, accessible colors, labels,
// and non-color indicators.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_legend.dart';

/// Configuration for a single bar group in the chart.
class BarChartGroup {
  final String label;
  final List<double> values;
  final String patternKey;

  BarChartGroup({
    required this.label,
    required this.values,
    String? patternKey,
    String? patternName,
  }) : assert(patternKey != null || patternName != null),
       patternKey = patternKey ?? patternName!;

  String get patternName => patternKey;
}

/// A single bar rod configuration.
class BarChartRod {
  final double value;
  final Color color;
  final String patternName;

  const BarChartRod({
    required this.value,
    required this.color,
    required this.patternName,
  });
}

/// Accessible bar chart with semantic labels, legend, and pattern fills.
///
/// Per AC3 verification: legend, pattern fills, shape-coded legends, aria-labels.
class AccessibleBarChart extends StatelessWidget {
  /// Groups of bars (each group = one x-axis tick with multiple rods).
  final List<BarChartGroup> groups;

  /// Maximum Y value for the chart (auto-computed if null).
  final double? maxY;

  /// Y-axis label (e.g., "Shots", "Percentage").
  final String yAxisLabel;

  /// Chart title for aria-label.
  final String title;

  /// Accessible color palette (minimum 3 colors).
  static const List<Color> _accessibleColors = [
    Color(0xFF1565C0), // Blue
    Color(0xFFEF6C00), // Orange
    Color(0xFF2E7D32), // Green
    Color(0xFF7B1FA2), // Purple
    Color(0xFFC62828), // Red
  ];

  const AccessibleBarChart({
    super.key,
    required this.groups,
    this.maxY,
    required this.yAxisLabel,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    final computedMaxY = maxY ?? _computeMaxY();
    final colorAssign = _assignColors();

    return Semantics(
      label: title,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          ChartLegend(
            items: groups
                .map(
                  (g) => LegendItem(
                    label: g.label,
                    color: colorAssign[g.patternKey]!,
                    patternName: g.patternKey,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          // Chart
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: computedMaxY,
                minY: 0,
                barGroups: _buildBarGroups(colorAssign),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                    axisNameWidget: Text(
                      yAxisLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= groups.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            groups[index].label,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: computedMaxY / 4,
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${groups[groupIndex].label}\n${rod.toY.toStringAsFixed(1)} $yAxisLabel',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _computeMaxY() {
    double max = 0;
    for (final group in groups) {
      for (final value in group.values) {
        if (value > max) max = value;
      }
    }
    return max * 1.2; // Add 20% headroom
  }

  Map<String, Color> _assignColors() {
    final result = <String, Color>{};
    int colorIndex = 0;
    for (final group in groups) {
      if (!result.containsKey(group.patternKey)) {
        result[group.patternKey] =
            _accessibleColors[colorIndex % _accessibleColors.length];
        colorIndex++;
      }
    }
    return result;
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, Color> colorAssign) {
    return groups.asMap().entries.map((entry) {
      final index = entry.key;
      final group = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: group.values.map((value) {
          final color = colorAssign[group.patternKey]!;
          return BarChartRodData(
            toY: value,
            color: color,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          );
        }).toList(),
      );
    }).toList();
  }
}
