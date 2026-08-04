// WindArrowOverlay — VSP Mobile App
//
// Flutter-rendered wind direction arrow with speed label and relative-wind
// components. Positioned as an overlay on the map corner.
//
// Accessibility: all wind information is conveyed via text labels, not color
// alone. Screen-reader users receive a full Semantics label describing absolute
// wind, relative-wind components, and staleness.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:vsp_mobile/features/hole_map/domain/wind_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/wind_relative_entity.dart';

/// Overlay widget showing wind direction arrow, speed, and relative-wind
/// components (headwind / tailwind / crosswind) derived from the shot line.
///
/// Accepts [wind] as the source wind data. When [windRelative] is provided
/// the widget also displays headwind/tailwind and crosswind labels in text
/// form, ensuring accessibility does not depend on color alone.
class WindArrowOverlay extends StatelessWidget {
  /// Source wind data (direction + speed).
  final WindEntity wind;

  /// Optional wind components relative to the shot line.
  /// When provided, the overlay shows headwind/tailwind/crosswind text labels.
  final WindRelativeEntity? windRelative;

  const WindArrowOverlay({super.key, required this.wind, this.windRelative});

  @override
  Widget build(BuildContext context) {
    final isStale = windRelative?.isStale ?? false;
    final hasRelative = windRelative != null && !isStale;

    // Build component labels
    String componentText;
    if (isStale) {
      componentText = 'Wind stale';
    } else if (hasRelative) {
      componentText = _buildComponentLabel(windRelative!);
    } else {
      componentText = '';
    }

    return Semantics(
      label: _buildSemanticsLabel(isStale, hasRelative),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isStale
                ? const Color(0xFFF59E0B).withOpacity(0.8)
                : const Color(0xFF38BDF8).withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Arrow rotated to wind direction
            // Rotation is a semantic orientation cue, not decorative animation
            Transform.rotate(
              angle: _radians(wind.direction),
              child: Icon(
                Icons.navigation,
                size: 18,
                color: isStale
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary wind speed
                Text(
                  '${wind.speed.toStringAsFixed(1)} ${wind.unit ?? 'km/h'}',
                  style: TextStyle(
                    color: isStale
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFF8FAFC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Cardinal direction
                Text(
                  wind.cardinalDirection,
                  style: TextStyle(
                    color: isStale
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF38BDF8),
                    fontSize: 10,
                  ),
                ),
                // Relative-wind component (if available and not stale)
                if (componentText.isNotEmpty)
                  Text(
                    componentText,
                    style: TextStyle(
                      color: isStale
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF94A3B8),
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a short text label for the dominant relative-wind component.
  String _buildComponentLabel(WindRelativeEntity relative) {
    if (relative.hasNoComponents) return '';

    // Show the larger of head/tail vs crosswind
    final headTail = (relative.headwind ?? 0).abs().clamp(0.0, double.infinity);
    final crossLeft = (relative.crosswindLeft ?? 0).abs().clamp(
      0.0,
      double.infinity,
    );
    final crossRight = (relative.crosswindRight ?? 0).abs().clamp(
      0.0,
      double.infinity,
    );
    final crosswind = (crossLeft > crossRight ? crossLeft : crossRight).clamp(
      0.0,
      double.infinity,
    );

    if (headTail >= crosswind) {
      // Show headwind or tailwind
      if ((relative.headwind ?? 0) > 0) {
        return '${relative.headwind!.toStringAsFixed(0)} km/h headwind';
      } else if ((relative.tailwind ?? 0) > 0) {
        return '${relative.tailwind!.toStringAsFixed(0)} km/h tailwind';
      }
    }

    // Show crosswind
    if ((relative.crosswindLeft ?? 0).abs() >=
        (relative.crosswindRight ?? 0).abs()) {
      final val = relative.crosswindLeft!.abs().toStringAsFixed(0);
      return '$val km/h from left';
    } else {
      final val = relative.crosswindRight!.abs().toStringAsFixed(0);
      return '$val km/h from right';
    }
  }

  /// Builds a comprehensive screen-reader label.
  String _buildSemanticsLabel(bool isStale, bool hasRelative) {
    final base =
        'Wind ${wind.speed.toStringAsFixed(1)} '
        '${wind.unit ?? 'km/h'} from ${wind.cardinalDirection}';

    if (isStale) {
      return '$base. Wind data stale.';
    }

    if (!hasRelative) return base;

    final rel = windRelative!;
    final parts = <String>[];

    if ((rel.headwind ?? 0) > 0) {
      parts.add('${rel.headwind!.toStringAsFixed(0)} km/h headwind');
    } else if ((rel.tailwind ?? 0) > 0) {
      parts.add('${rel.tailwind!.toStringAsFixed(0)} km/h tailwind');
    }

    if ((rel.crosswindLeft ?? 0).abs() >= (rel.crosswindRight ?? 0).abs()) {
      final val = rel.crosswindLeft!.abs().toStringAsFixed(0);
      if (val != '0') {
        parts.add('crosswind from left $val km/h');
      }
    } else {
      final val = rel.crosswindRight!.abs().toStringAsFixed(0);
      if (val != '0') {
        parts.add('crosswind from right $val km/h');
      }
    }

    if (parts.isEmpty) return base;
    return '$base. ${parts.join('. ')}.';
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
