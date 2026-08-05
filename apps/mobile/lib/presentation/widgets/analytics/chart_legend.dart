// Chart Legend — VSP Mobile App
//
// Shared legend widget with shape/pattern/color coding.
// Per Story 11.2 AC3: non-color indicators for accessibility.

import 'package:flutter/material.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A single legend item combining color, shape, and label.
class LegendItem {
  /// Display label.
  final String label;

  /// Fill color.
  final Color color;

  /// Pattern/shape name for non-color identification.
  final String patternName;

  const LegendItem({
    required this.label,
    required this.color,
    required this.patternName,
  });
}

/// Accessible chart legend with shape-coded entries.
///
/// Per AC3: non-color coding for wind direction and chart differentiation.
class ChartLegend extends StatelessWidget {
  final List<LegendItem> items;
  final AxisDirection direction;

  const ChartLegend({
    super.key,
    required this.items,
    this.direction = AxisDirection.right,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isHorizontal =
        direction == AxisDirection.left || direction == AxisDirection.right;

    return Semantics(
      label: AppLocalizations.of(context).analyticsChartLegend,
      child: Wrap(
        direction: isHorizontal ? Axis.horizontal : Axis.vertical,
        spacing: 16,
        runSpacing: 8,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _LegendEntry(item: item, shapeIndex: index);
        }).toList(),
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final LegendItem item;
  final int shapeIndex;

  const _LegendEntry({required this.item, required this.shapeIndex});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.label}, ${item.patternName}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color swatch
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 6),
          // Shape indicator for non-color identification
          _buildShapeIndicator(context),
          const SizedBox(width: 4),
          // Label
          Text(item.label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildShapeIndicator(BuildContext context) {
    // Assign shapes based on index for non-color differentiation
    final shapeName = _shapeName(shapeIndex);
    return Tooltip(
      message: AppLocalizations.of(context).analyticsShapeLabel(shapeName),
      child: Icon(
        _shapeIcon(shapeIndex),
        size: 12,
        color: Colors.grey.shade600,
      ),
    );
  }

  String _shapeName(int index) {
    switch (index % 4) {
      case 0:
        return 'circle';
      case 1:
        return 'square';
      case 2:
        return 'triangle';
      case 3:
        return 'diamond';
      default:
        return 'circle';
    }
  }

  IconData _shapeIcon(int index) {
    switch (index % 4) {
      case 0:
        return Icons.circle;
      case 1:
        return Icons.square;
      case 2:
        return Icons.change_history; // triangle
      case 3:
        return Icons.diamond;
      default:
        return Icons.circle;
    }
  }
}
