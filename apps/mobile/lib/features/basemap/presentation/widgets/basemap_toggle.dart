// Basemap Toggle — VSP Mobile App
//
// Switches the hole map between the vector course map and satellite imagery.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Which basemap the hole map is showing.
/// Which basemap the golfer last chose, for as long as the app is running.
///
/// The hole map is rebuilt from scratch on every hole — a hole change is a new
/// camera, a new basemap decision and a new measuring session — so a golfer who
/// switched to satellite on the 1st was handed the vector map again on the 2nd,
/// and on every hole after that. Remembering the choice is what makes satellite
/// a mode rather than something to re-select eighteen times.
///
/// Deliberately not persisted to disk: it is a preference for this round, not a
/// setting, and a golfer who closes the app should reopen on the map their
/// course data supports.
abstract final class BasemapPreference {
  /// Satellite first.
  ///
  /// The vector map draws what the package holds: on most holes a derived
  /// rectangle for the fairway and nothing at all for water. The photograph
  /// underneath is the actual course, and it is the same picture the golfer is
  /// standing in. The strategic map is the deliberate second look, not the
  /// thing that greets them.
  static BasemapMode _chosen = BasemapMode.satellite;

  /// What the golfer last picked.
  static BasemapMode get chosen => _chosen;

  /// Records a deliberate choice. Not called for the automatic switch to
  /// satellite on a hole with no geometry — that is the app deciding, not the
  /// golfer, and it must not overwrite what they asked for.
  static void choose(BasemapMode mode) => _chosen = mode;

  /// Test seam.
  static void resetForTesting() => _chosen = BasemapMode.satellite;
}

enum BasemapMode {
  /// Vector course geometry from the downloaded course package.
  courseMap,

  /// The manual measuring tool, over satellite imagery where the build has a
  /// provider configured and over a plain canvas where it does not.
  satellite,
}

/// Compact two-way switch between the course map and satellite imagery.
class BasemapToggle extends StatelessWidget {
  /// Currently selected mode.
  final BasemapMode mode;

  /// Called with the newly selected mode.
  final ValueChanged<BasemapMode> onChanged;

  /// False when this build has no imagery provider configured.
  ///
  /// The option stays enabled either way — what is behind it is the measuring
  /// tool, which works from GPS and needs no pictures. Only the wording
  /// changes, from "Satellite" to "Measure", so the button never promises
  /// imagery this build cannot fetch. It used to be disabled here, which on a
  /// database where every hole is unverified locked the golfer out of the only
  /// distance tool they had.
  final bool satelliteAvailable;

  /// Icons only, for a corner of the map.
  ///
  /// Labelled, this control is about 205dp wide on a 402dp phone — half the
  /// screen for a switch the file's own note says is "pressed once a round, if
  /// that". Sharing the foot of the map with the distances meant one of them
  /// had to give up a third of itself, and a run where it did came back
  /// reading "B…" and "Th…". Given a line of its own instead, it floated into
  /// the middle of the map as soon as the panels beneath it grew.
  ///
  /// Two icons fit in a corner and cost nothing: the full wording stays in the
  /// Semantics label, so a screen reader still hears "switch to the course
  /// map".
  final bool compact;

  const BasemapToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.satelliteAvailable = true,
    this.compact = false,
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
      // Flexible, not fixed.
      //
      // At twice the system text size the two labels together are wider than
      // the phone. Nothing said so: the switch was positioned by its right
      // edge with no width to fit inside, so it simply extended off the left
      // of the screen and the golfer lost the control that gets them to the
      // measuring tool. It only became an error — an 83px overflow — once the
      // top of the map became a Row that had to hold both this and the
      // provenance notice.
      //
      // Each half now yields, and the label ellipsises rather than the switch
      // leaving the screen. The full wording stays in the Semantics label, so
      // a screen reader still hears "switch to the course map".
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _Option(
              icon: Icons.map_outlined,
              label: l10n.basemapCourseMap,
              semanticLabel: l10n.basemapSwitchToCourseMap,
              selected: mode == BasemapMode.courseMap,
              enabled: true,
              compact: compact,
              onTap: () => onChanged(BasemapMode.courseMap),
            ),
          ),
          Flexible(
            child: _Option(
              icon: satelliteAvailable
                  ? Icons.satellite_alt_outlined
                  : Icons.straighten,
              label: satelliteAvailable
                  ? l10n.basemapSatellite
                  : l10n.basemapMeasure,
              semanticLabel: satelliteAvailable
                  ? l10n.basemapSwitchToSatellite
                  : l10n.basemapSwitchToMeasure,
              selected: mode == BasemapMode.satellite,
              enabled: true,
              compact: compact,
              onTap: () => onChanged(BasemapMode.satellite),
            ),
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
  final bool compact;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.compact = false,
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
              Icon(icon, size: compact ? 20 : 16, color: color),
              if (!compact) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
