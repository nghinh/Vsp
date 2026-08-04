// Accessible Pie Chart — VSP Mobile App
//
// fl_chart PieChart wrapper with legend, non-color indicators, and aria-labels.
// Per Story 11.2 AC3: charts include legends, accessible colors, labels,
// and non-color indicators.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_legend.dart';

/// Configuration for a pie chart section.
class PieChartSection {
  final String label;
  final double value;
  final String patternName;

  const PieChartSection({
    required this.label,
    required this.value,
    required this.patternName,
  });
}

/// Accessible pie chart with semantic legend and pattern/shape coding.
///
/// Per AC3 verification: legend, pattern fills, shape-coded legends, aria-labels.
class AccessiblePieChart extends StatelessWidget {
  final List<PieChartSection> sections;

  /// Chart title for aria-label.
  final String title;

  /// Accessible color palette with sufficient contrast.
  static const List<Color> _accessibleColors = [
    Color(0xFF1565C0), // Blue
    Color(0xFFEF6C00), // Orange
    Color(0xFF2E7D32), // Green
    Color(0xFF7B1FA2), // Purple
    Color(0xFFC62828), // Red
    Color(0xFF00838F), // Teal
    Color(0xFFAD1457), // Pink
    Color(0xFF4E342E), // Brown
  ];

  const AccessiblePieChart({
    super.key,
    required this.sections,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = sections.fold(0.0, (sum, s) => sum + s.value);
    if (total == 0) {
      return const SizedBox.shrink();
    }

    final colorAssign = _assignColors();

    return Semantics(
      label: title,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          ChartLegend(
            items: sections.map((s) {
              final pct = (s.value / total * 100).toStringAsFixed(1);
              return LegendItem(
                label: '${s.label} ($pct%)',
                color: colorAssign[s.patternName]!,
                patternName: s.patternName,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Pie chart
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final section = entry.value;
                  final color = colorAssign[section.patternName]!;
                  final pct = section.value / total * 100;
                  return PieChartSectionData(
                    value: section.value,
                    color: color,
                    title: pct > 5 ? '${pct.toStringAsFixed(0)}%' : '',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    radius: 80,
                    badgeWidget: _buildBadge(index, section.patternName),
                    badgePositionPercentageOffset: 1.15,
                  );
                }).toList(),
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Color> _assignColors() {
    final result = <String, Color>{};
    int colorIndex = 0;
    for (final section in sections) {
      if (!result.containsKey(section.patternName)) {
        result[section.patternName] =
            _accessibleColors[colorIndex % _accessibleColors.length];
        colorIndex++;
      }
    }
    return result;
  }

  /// Build a shape badge for non-color identification.
  Widget _buildBadge(int index, String patternName) {
    // Different shapes based on pattern index for accessibility
    final shapeIndex = index % 4;
    IconData icon;
    switch (shapeIndex) {
      case 0:
        icon = Icons.circle;
        break;
      case 1:
        icon = Icons.square;
        break;
      case 2:
        icon = Icons.change_history;
        break;
      case 3:
        icon = Icons.diamond;
        break;
      default:
        icon = Icons.circle;
    }
    return Icon(icon, size: 12, color: Colors.black54);
  }
}
