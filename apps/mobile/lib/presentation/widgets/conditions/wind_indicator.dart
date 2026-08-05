// WindIndicator — VSP Mobile App
//
// Story 7.1 Wave 3: Wind Indicator on Map
// Per slice plan §3.2 — compact display of direction + speed on map overlay.
//
// Accessibility:
// - Accessible label: "Wind from SE at 15 km/h"
// - All wind information conveyed via text labels, not color alone

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/wind_data.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Compact wind indicator for map overlay.
///
/// Displays:
/// - Wind direction arrow (rotated)
/// - Speed in km/h
/// - Cardinal direction text
///
/// Accessibility: full text label via Semantics.
class WindIndicator extends StatelessWidget {
  /// Wind data to display.
  final WindData wind;

  /// Whether the data is stale.
  final bool isStale;

  /// Callback when tapped (shows full conditions panel).
  final VoidCallback? onTap;

  const WindIndicator({
    super.key,
    required this.wind,
    this.isStale = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;
    final arrowColor = isStale
        ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706))
        : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9));
    final backgroundColor = isDark
        ? const Color(0xFF1E293B).withOpacity(0.92)
        : Colors.white.withOpacity(0.92);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Semantics(
      label: _accessibleLabel(context),
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isStale
                  ? const Color(0xFFF59E0B).withOpacity(0.6)
                  : arrowColor.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Direction arrow (rotates to wind direction)
              Transform.rotate(
                angle: wind.degrees * math.pi / 180,
                child: Icon(
                  Icons.navigation,
                  size: 18,
                  color: arrowColor,
                  semanticLabel: AppLocalizations.of(context).weatherWindDirection(wind.direction.displayName),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speed
                  Text(
                    '${wind.speedKmh.toStringAsFixed(0)} km/h',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    semanticsLabel:
                        '${wind.speedKmh.toStringAsFixed(1)} kilometers per hour',
                  ),
                  // Cardinal direction
                  Text(
                    wind.direction.label,
                    style: TextStyle(
                      color: arrowColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    semanticsLabel: 'from ${wind.direction.displayName}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _accessibleLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = l10n.weatherWindFromAtVerbose(
      wind.direction.label,
      wind.speedKmh.toStringAsFixed(1),
    );
    if (isStale) return '${base}. ${l10n.weatherWindStaleWarning}';
    return base;
  }
}
