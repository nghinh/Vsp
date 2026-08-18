// GolferPositionMarker — VSP Mobile App
//
// Flutter-rendered GPS position marker with accuracy circle indicator.
// Follows high-contrast outdoor design tokens from UX spec.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';

import 'package:vsp_mobile/features/hole_map/domain/golfer_position_entity.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Displays the golfer's current GPS position as a marker badge
/// with accuracy and confidence indicator.
class GolferPositionMarker extends StatelessWidget {
  final GolferPositionEntity position;

  const GolferPositionMarker({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          AppLocalizations.of(
            context,
          ).mapGolferPositionSemantics(position.confidence.name) +
          (position.accuracy == null
              ? ''
              : AppLocalizations.of(context).mapGolferAccuracySuffix(
                  position.accuracy!.toStringAsFixed(0),
                )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _confidenceColor.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GolferDot(confidence: position.confidence),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YOU',
                  style: TextStyle(
                    color: _confidenceColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (position.accuracy != null)
                  Text(
                    // In the golfer's own unit; a tolerance is a distance.
                    MeasureUnits.formatTolerance(
                      position.accuracy!,
                      DistanceUnitScope.watch(context),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _confidenceColor {
    switch (position.confidence) {
      case PositionConfidence.high:
        return const Color(0xFF22C55E); // green
      case PositionConfidence.medium:
        return const Color(0xFFF97316); // amber
      case PositionConfidence.low:
        return const Color(0xFFDC2626); // red
    }
  }
}

class _GolferDot extends StatelessWidget {
  final PositionConfidence confidence;

  const _GolferDot({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _dotColor,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _dotColor.withOpacity(0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Color get _dotColor {
    switch (confidence) {
      case PositionConfidence.high:
        return const Color(0xFF3B82F6); // blue
      case PositionConfidence.medium:
        return const Color(0xFFF97316); // amber
      case PositionConfidence.low:
        return const Color(0xFFDC2626); // red
    }
  }
}
