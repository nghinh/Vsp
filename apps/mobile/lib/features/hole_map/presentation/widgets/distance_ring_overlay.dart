// DistanceRingOverlay — VSP Mobile App
//
// Legend displaying active distance rings with radius labels.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/features/hole_map/domain/distance_ring_entity.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Legend widget showing the active distance rings and their labels.
class DistanceRingOverlay extends StatelessWidget {
  final List<DistanceRingEntity> rings;

  const DistanceRingOverlay({super.key, required this.rings});

  @override
  Widget build(BuildContext context) {
    final visibleRings = rings.where((r) => r.visible).toList();

    return Semantics(
      label: AppLocalizations.of(
        context,
      ).mapDistanceRingsLabel(visibleRings.map((r) => r.label).join(', ')),
      child: Container(
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
              AppLocalizations.of(context).mapDistanceRingsTitle,
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            ...visibleRings.map(
              (ring) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF8FAFC).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ring.label ?? '${ring.radiusMeters}m',
                      style: const TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
