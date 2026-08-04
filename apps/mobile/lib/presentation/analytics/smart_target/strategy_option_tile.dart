// StrategyOptionTile — VSP Mobile App
//
// Individual strategy option row for Smart Target selection.
//
// Per slice-plan-11-4.md Slice 3:
// - Individual option row for strategy selection
// - One-hand/two-tap: selection completes in ≤2 taps
// - Accessibility: semantics labels, 44dp touch targets
//
// Story 11.4 — Slice 3: State Management + UI Shell

import 'package:flutter/material.dart';

import '../../../domain/analytics/smart_target/models/strategy_option.dart';
import '../../../domain/analytics/smart_target/models/strategy_type.dart';

/// Strategy option tile for Smart Target selection.
///
/// Displays a single strategy option (safe/balanced/aggressive) as a tappable row.
/// Selection completes in one tap (≤2 tap requirement).
///
/// Accessibility:
/// - Full row is tappable with semantic label
/// - Touch target ≥44dp height
/// - Color + text indicators (not color-only)
class StrategyOptionTile extends StatelessWidget {
  /// The strategy option to display.
  final StrategyOption option;

  /// Whether this option is currently selected.
  final bool isSelected;

  /// Callback when this option is tapped.
  final VoidCallback? onTap;

  const StrategyOptionTile({
    super.key,
    required this.option,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: _semanticLabel,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? _selectedColor(colorScheme).withOpacity(0.1)
                : colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? _selectedColor(colorScheme)
                  : colorScheme.outline.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Strategy type icon
              _StrategyIcon(
                strategyType: option.strategyType,
                isSelected: isSelected,
              ),

              const SizedBox(width: 10),

              // Strategy details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.strategyType.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? _selectedColor(colorScheme)
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${option.clubName} · ${option.carryMeters.round()}m carry',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Risk indicator
              _RiskIndicator(
                riskScore: option.riskScore,
                isSelected: isSelected,
              ),

              const SizedBox(width: 8),

              // Selection indicator
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: _selectedColor(colorScheme),
                  semanticLabel: 'Selected',
                )
              else
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                  semanticLabel: 'Not selected',
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _semanticLabel {
    final type = option.strategyType.displayName;
    final club = option.clubName;
    final carry = option.carryMeters.round();
    final risk = option.riskScore;
    final selected = isSelected ? 'selected' : 'not selected';
    return '$type strategy, $club club, $carry meters carry, '
        'risk $risk out of 100. $selected.';
  }

  Color _selectedColor(ColorScheme colorScheme) {
    switch (option.strategyType) {
      case StrategyType.safe:
        return Colors.green;
      case StrategyType.balanced:
        return Colors.amber.shade700;
      case StrategyType.aggressive:
        return Colors.red;
    }
  }
}

/// Strategy type icon.
class _StrategyIcon extends StatelessWidget {
  final StrategyType strategyType;
  final bool isSelected;

  const _StrategyIcon({required this.strategyType, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color color;
    IconData icon;

    switch (strategyType) {
      case StrategyType.safe:
        color = Colors.green;
        icon = Icons.shield;
        break;
      case StrategyType.balanced:
        color = Colors.amber.shade700;
        icon = Icons.balance;
        break;
      case StrategyType.aggressive:
        color = Colors.red;
        icon = Icons.trending_up;
        break;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(0.15)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 20,
        color: isSelected ? color : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Risk indicator badge.
class _RiskIndicator extends StatelessWidget {
  final int riskScore;
  final bool isSelected;

  const _RiskIndicator({required this.riskScore, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color color;
    if (riskScore < 25) {
      color = Colors.green;
    } else if (riskScore < 50) {
      color = Colors.amber;
    } else if (riskScore < 75) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Semantics(
      label: 'Risk: $riskScore',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              '$riskScore',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
