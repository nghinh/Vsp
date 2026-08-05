// Basemap Toggle — VSP Mobile App
//
// Switches the hole map between the vector course map and satellite imagery.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Which basemap the hole map is showing.
enum BasemapMode {
  /// Vector course geometry from the downloaded course package.
  courseMap,

  /// Satellite imagery plus the manual measuring tool.
  satellite,
}

/// Compact two-way switch between the course map and satellite imagery.
class BasemapToggle extends StatelessWidget {
  /// Currently selected mode.
  final BasemapMode mode;

  /// Called with the newly selected mode.
  final ValueChanged<BasemapMode> onChanged;

  /// False when this build has no imagery provider configured; the satellite
  /// option is then shown disabled rather than hidden, so the golfer can see
  /// the feature exists and support can explain why it is off.
  final bool satelliteAvailable;

  const BasemapToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.satelliteAvailable = true,
  });

  static const Color _surface = Color(0xE6131C2F);
  static const Color _border = Color(0x33FFFFFF);
  static const Color _selected = Color(0xFFEA580C);
  static const Color _text = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Option(
            icon: Icons.map_outlined,
            label: l10n.basemapCourseMap,
            semanticLabel: l10n.basemapSwitchToCourseMap,
            selected: mode == BasemapMode.courseMap,
            enabled: true,
            onTap: () => onChanged(BasemapMode.courseMap),
          ),
          _Option(
            icon: Icons.satellite_alt_outlined,
            label: l10n.basemapSatellite,
            semanticLabel: satelliteAvailable
                ? l10n.basemapSwitchToSatellite
                : l10n.basemapSatelliteUnavailableTitle,
            selected: mode == BasemapMode.satellite,
            enabled: satelliteAvailable,
            onTap: () => onChanged(BasemapMode.satellite),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? BasemapToggle._textMuted
        : selected
        ? BasemapToggle._text
        : BasemapToggle._textMuted;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected && enabled
                ? BasemapToggle._selected
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
