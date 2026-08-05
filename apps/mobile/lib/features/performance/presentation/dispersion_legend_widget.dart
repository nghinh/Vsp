// DispersionLegendWidget — VSP Mobile App
//
// Legend showing shot outcome colors and layer toggles.
// Per Story 11.1 AC-3 and Slice 4.
//
// Shows: result color legend, count per category, layer toggle buttons.

import 'package:flutter/material.dart';

import 'package:mobile_theme/mobile_theme.dart';
import '../../../../domain/models/performance/dispersion_overlay.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

// ─── Legend Widget ─────────────────────────────────────────────────────────────

/// Legend widget showing dispersion outcome colors and layer toggles.
class DispersionLegendWidget extends StatelessWidget {
  final DispersionOverlay overlay;
  final bool showHazards;
  final bool showScatter;
  final VoidCallback onToggleHazards;
  final VoidCallback onToggleScatter;

  const DispersionLegendWidget({
    super.key,
    required this.overlay,
    required this.showHazards,
    required this.showScatter,
    required this.onToggleHazards,
    required this.onToggleScatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = colorScheme.brightness;
    final isDark = brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E293B) : colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            'Dispersion',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Outcome legend
          _OutcomeLegendItem(
            color: _ResultColors.fairway(isDark),
            label: AppLocalizations.of(context).dispersionFairway,
            count: overlay.fairwayCount,
          ),
          _OutcomeLegendItem(
            color: _ResultColors.rough(isDark),
            label: AppLocalizations.of(context).dispersionRough,
            count: overlay.outcomeCounts['ROUGH'] ?? 0,
          ),
          _OutcomeLegendItem(
            color: _ResultColors.bunker(isDark),
            label: AppLocalizations.of(context).dispersionBunker,
            count: overlay.outcomeCounts['BUNKER'] ?? 0,
          ),
          _OutcomeLegendItem(
            color: _ResultColors.water(isDark),
            label: AppLocalizations.of(context).dispersionWater,
            count: overlay.outcomeCounts['WATER'] ?? 0,
          ),
          _OutcomeLegendItem(
            color: _ResultColors.ob(isDark),
            label: AppLocalizations.of(context).dispersionOb,
            count: overlay.obCount,
          ),

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),

          // Layer toggles
          _LayerToggle(
            icon: Icons.scatter_plot,
            label: AppLocalizations.of(context).dispersionScatter,
            isActive: showScatter,
            onTap: onToggleScatter,
          ),
          const SizedBox(height: 4),
          _LayerToggle(
            icon: Icons.warning_amber,
            label: AppLocalizations.of(context).dispersionHazards,
            isActive: showHazards,
            onTap: onToggleHazards,
          ),
        ],
      ),
    );
  }
}

// ─── Outcome Legend Item ──────────────────────────────────────────────────────

class _OutcomeLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _OutcomeLegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '$count shots in $label',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Layer Toggle ─────────────────────────────────────────────────────────────

class _LayerToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LayerToggle({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: '$label layer ${isActive ? 'visible' : 'hidden'}',
        button: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primaryContainer.withOpacity(0.5)
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? colorScheme.primary.withOpacity(0.5)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isActive ? Icons.visibility : Icons.visibility_off,
                size: 12,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Result Colors ────────────────────────────────────────────────────────────

/// Color definitions for shot result categories.
abstract final class _ResultColors {
  static Color fairway(bool isDark) =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

  static Color rough(bool isDark) =>
      isDark ? const Color(0xFF84CC16) : const Color(0xFF65A30D);

  static Color bunker(bool isDark) =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFF97316);

  static Color water(bool isDark) =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  static Color ob(bool isDark) =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
}
