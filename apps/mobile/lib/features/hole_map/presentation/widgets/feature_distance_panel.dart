// What is in front of the golfer, and how far — VSP Mobile App
//
// The shapes on the map are only useful once they have numbers on them. A
// golfer standing on a tee asks three questions in a row: what is out there,
// how far to carry it, how far to the middle of the green.
//
// Ordered by distance, nearest first, and only what is still ahead. A bunker
// behind the golfer is scenery.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// One shape, measured from where the golfer stands.
class FeatureDistance {
  const FeatureDistance({
    required this.label,
    required this.nearMeters,
    required this.farMeters,
    required this.colour,
  });

  /// "Bunker", "Hồ nước", "Green" — already in the golfer's language.
  final String label;

  /// The near edge and the far edge. For a bunker these are the two numbers
  /// that decide a club: what it takes to reach it and what it takes to
  /// carry it.
  final double nearMeters;
  final double farMeters;

  final Color colour;
}

class FeatureDistancePanel extends StatelessWidget {
  const FeatureDistancePanel({
    super.key,
    required this.features,
    required this.unit,
  });

  final List<FeatureDistance> features;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const Key('feature_distance_panel'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF64748B).withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.mapFeatureDistances,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: feature.colour,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(
                    width: 86,
                    child: Text(
                      feature.label,
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    // Two numbers where the far edge is meaningfully past
                    // the near one — "142 / 158" is what a golfer needs to
                    // pick a club. One number where they are close enough
                    // that the second says nothing.
                    feature.farMeters - feature.nearMeters > 8
                        ? '${MeasureUnits.displayValue(feature.nearMeters, unit)}'
                            ' / '
                            '${MeasureUnits.format(feature.farMeters, unit)}'
                        : MeasureUnits.format(feature.nearMeters, unit),
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontFamily: 'Fira Code',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
