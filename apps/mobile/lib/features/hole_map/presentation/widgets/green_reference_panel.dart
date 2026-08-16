// Front / Centre / Back to the green — VSP Mobile App
//
// The three numbers a golfer reads before every approach, stacked the way a
// laser rangefinder or a cart GPS shows them: back on top, centre bold in the
// middle, front at the bottom, because that is the order they lie on the
// ground as the shot flies over them.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';

class GreenReferencePanel extends StatelessWidget {
  const GreenReferencePanel({
    super.key,
    required this.frontMeters,
    required this.centreMeters,
    required this.backMeters,
    required this.unit,
  });

  final double frontMeters;
  final double centreMeters;
  final double backMeters;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('green_reference_panel'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14331F).withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.mapGreenLabel.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF86EFAC),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          _row(l10n.mapGreenBack, backMeters, bold: false),
          _row(l10n.mapGreenCentre, centreMeters, bold: true),
          _row(l10n.mapGreenFront, frontMeters, bold: false),
        ],
      ),
    );
  }

  Widget _row(String label, double metres, {required bool bold}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFFCBD5E1),
                fontSize: bold ? 11 : 10,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            MeasureUnits.format(metres, unit),
            style: TextStyle(
              color: Colors.white,
              fontSize: bold ? 20 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
