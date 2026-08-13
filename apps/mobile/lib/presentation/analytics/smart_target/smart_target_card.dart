// SmartTargetCard — VSP Mobile App
//
// Strategy detail card for Smart Target recommendations.
//
// Per slice-plan-11-4.md Slice 3:
// - Displays selected strategy details
// - Risk score and confidence visible with color + text
// - Explanation displayed
//
// Story 11.4 — Slice 3: State Management + UI Shell

import 'package:flutter/material.dart';

import '../../../domain/analytics/smart_target/models/strategy_option.dart';
import '../../../domain/analytics/smart_target/models/strategy_type.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

/// Smart Target strategy detail card.
///
/// Shows the details of the currently selected strategy option:
/// - Club name and carry distance
/// - Risk score (color-coded)
/// - Confidence score (color-coded)
/// - Remaining distance to pin
/// - Hazards near landing zone
/// - Human-readable explanation
///
/// Accessibility:
/// - All values have semantic labels
/// - Color + text indicators (not color-only)
/// - 44dp+ touch targets
class SmartTargetCard extends StatelessWidget {
  /// The strategy option to display.
  final StrategyOption option;

  /// Callback when edit/tweak is requested.
  final VoidCallback? onEditAim;

  const SmartTargetCard({super.key, required this.option, this.onEditAim});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: _semanticLabelIn(context.distanceUnit),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Club name + strategy type badge
            _buildHeader(context, colorScheme),

            const SizedBox(height: 12),

            // Distance metrics row
            _buildDistanceMetrics(context),

            const SizedBox(height: 12),

            // Risk and confidence row
            _buildRiskConfidenceRow(context, colorScheme),

            // Hazards section
            if (option.hazardsAtLanding.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildHazardsSection(context, colorScheme),
            ],

            // Explanation
            if (option.explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildExplanation(context),
            ],
          ],
        ),
      ),
    );
  }

  String _semanticLabelIn(DistanceUnit unit) {
    final club = option.clubName;
    final carry = MeasureUnits.format(option.carryMeters, unit);
    final remaining = MeasureUnits.format(option.remainingMeters, unit);
    final risk = option.riskScore;
    final confidence = (option.confidenceScore * 100).round();
    return '$club, carry $carry, $remaining to pin, '
        'risk $risk out of 100, confidence $confidence percent. '
        '${option.explanation}';
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.clubName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (option.loftDegrees != null)
                Text(
                  '${option.loftDegrees}° loft',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        _StrategyTypeBadge(strategyType: option.strategyType),
      ],
    );
  }

  Widget _buildDistanceMetrics(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.straighten,
            label: AppLocalizations.of(context).smartTargetCarry,
            value: context.formatDistance(option.carryMeters),
            semanticLabel:
                'Carry distance: ${context.formatDistance(option.carryMeters)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            icon: Icons.flag,
            label: AppLocalizations.of(context).smartTargetToPin,
            value: context.formatDistance(option.remainingMeters),
            semanticLabel:
                'Distance to pin: ${context.formatDistance(option.remainingMeters)}',
          ),
        ),
      ],
    );
  }

  Widget _buildRiskConfidenceRow(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Expanded(child: _RiskScoreDisplay(riskScore: option.riskScore)),
        const SizedBox(width: 12),
        Expanded(
          child: _ConfidenceScoreDisplay(
            confidenceScore: option.confidenceScore,
          ),
        ),
      ],
    );
  }

  Widget _buildHazardsSection(BuildContext context, ColorScheme colorScheme) {
    final hazards = option.hazardsAtLanding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hazards Near Landing Zone',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: hazards.map((hazard) {
            return Chip(
              avatar: Icon(
                _hazardIcon(hazard.hazardType),
                size: 16,
                color: _hazardColor(hazard.hazardType, colorScheme),
              ),
              label: Text(
                hazard.hazardName,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: colorScheme.surfaceContainerHighest,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExplanation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
            semanticLabel: AppLocalizations.of(context).smartTargetExplanation,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.explanation,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _hazardIcon(String hazardType) {
    switch (hazardType) {
      case 'water':
        return Icons.water;
      case 'bunker':
        return Icons.landscape;
      case 'ob':
        return Icons.not_interested;
      case 'penalty':
        return Icons.warning;
      default:
        return Icons.warning_amber;
    }
  }

  Color _hazardColor(String hazardType, ColorScheme colorScheme) {
    switch (hazardType) {
      case 'water':
        return Colors.blue;
      case 'bunker':
        return Colors.brown;
      case 'ob':
        return Colors.red;
      case 'penalty':
        return Colors.orange;
      default:
        return colorScheme.error;
    }
  }
}

/// Strategy type badge.
class _StrategyTypeBadge extends StatelessWidget {
  final StrategyType strategyType;

  const _StrategyTypeBadge({required this.strategyType});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (strategyType) {
      case StrategyType.safe:
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        icon = Icons.shield;
        break;
      case StrategyType.balanced:
        backgroundColor = Colors.amber.shade50;
        textColor = Colors.amber.shade700;
        icon = Icons.balance;
        break;
      case StrategyType.aggressive:
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        icon = Icons.trending_up;
        break;
    }

    return Semantics(
      label: AppLocalizations.of(context).smartTargetStrategyLabel(strategyType.displayName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(
              strategyType.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Metric tile for displaying a labeled value.
class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String semanticLabel;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Risk score display with color coding.
class _RiskScoreDisplay extends StatelessWidget {
  final int riskScore;

  const _RiskScoreDisplay({required this.riskScore});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color color;
    String label;

    if (riskScore < 25) {
      color = Colors.green;
      label = 'Low';
    } else if (riskScore < 50) {
      color = Colors.amber;
      label = 'Medium';
    } else if (riskScore < 75) {
      color = Colors.orange;
      label = 'High';
    } else {
      color = Colors.red;
      label = 'Extreme';
    }

    return Semantics(
      label: AppLocalizations.of(context).smartTargetRiskDetail(label, '$riskScore'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  'Risk',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '$riskScore',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Confidence score display with color coding.
class _ConfidenceScoreDisplay extends StatelessWidget {
  final double confidenceScore;

  const _ConfidenceScoreDisplay({required this.confidenceScore});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = (confidenceScore * 100).round();

    Color color;
    String label;

    if (confidenceScore >= 0.8) {
      color = Colors.green;
      label = 'High';
    } else if (confidenceScore >= 0.5) {
      color = Colors.amber;
      label = 'Med';
    } else {
      color = Colors.red;
      label = 'Low';
    }

    return Semantics(
      label: AppLocalizations.of(context).smartTargetConfidence('$percentage', label),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  'Confidence',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '$percentage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
