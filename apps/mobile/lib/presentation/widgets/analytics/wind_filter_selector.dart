// Wind Filter Selector — VSP Mobile App
//
// Wind condition dropdown for the Driving Zone filter bar.
// Per AC1: wind filter wired to cubit; non-color indicators for accessibility.

import 'package:flutter/material.dart';

import '../../../domain/models/driving_zone_filter.dart';

/// Wind filter dropdown selector.
///
/// Displays wind condition options with non-color icons for accessibility.
class WindFilterSelector extends StatelessWidget {
  /// Currently selected wind condition (null = any).
  final WindCondition? selectedCondition;

  /// Called when wind condition selection changes.
  final ValueChanged<WindCondition?> onChanged;

  const WindFilterSelector({
    super.key,
    required this.selectedCondition,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.air, size: 18),
            const SizedBox(width: 8),
            const Text('Wind:', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<WindCondition?>(
          value: selectedCondition,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'Any',
          ),
          items: [
            const DropdownMenuItem<WindCondition?>(
              value: null,
              child: Text('Any'),
            ),
            ...WindCondition.values.map((condition) {
              return DropdownMenuItem<WindCondition?>(
                value: condition,
                child: Row(
                  children: [
                    _WindIcon(condition: condition),
                    const SizedBox(width: 8),
                    Text(_windLabel(condition)),
                  ],
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _windLabel(WindCondition condition) {
    switch (condition) {
      case WindCondition.any:
        return 'Any';
      case WindCondition.calm:
        return 'Calm (0-5 mph)';
      case WindCondition.light:
        return 'Light (6-12 mph)';
      case WindCondition.moderate:
        return 'Moderate (13-19 mph)';
      case WindCondition.windy:
        return 'Windy (20+ mph)';
      case WindCondition.headwind:
        return 'Headwind';
      case WindCondition.tailwind:
        return 'Tailwind';
      case WindCondition.crosswindLeft:
        return 'Crosswind Left';
      case WindCondition.crosswindRight:
        return 'Crosswind Right';
    }
  }
}

class _WindIcon extends StatelessWidget {
  final WindCondition condition;

  const _WindIcon({required this.condition});

  @override
  Widget build(BuildContext context) {
    // Non-color icon indicators for wind direction (accessibility)
    IconData icon;
    switch (condition) {
      case WindCondition.any:
        icon = Icons.all_inclusive;
        break;
      case WindCondition.calm:
      case WindCondition.light:
        icon = Icons.air;
        break;
      case WindCondition.moderate:
      case WindCondition.windy:
        icon = Icons.air;
        break;
      case WindCondition.headwind:
        icon = Icons.arrow_upward;
        break;
      case WindCondition.tailwind:
        icon = Icons.arrow_downward;
        break;
      case WindCondition.crosswindLeft:
        icon = Icons.arrow_back;
        break;
      case WindCondition.crosswindRight:
        icon = Icons.arrow_forward;
        break;
    }

    final semanticLabel = condition.name;
    return Icon(
      icon,
      size: 16,
      color: Colors.grey.shade600,
      semanticLabel: semanticLabel,
    );
  }
}
