// Front / Centre / Back to the green — VSP Mobile App
//
// The three numbers a golfer reads before every approach, stacked the way a
// laser rangefinder or a cart GPS shows them: back on top, centre in the
// middle, front at the bottom, because that is the order they lie on the
// ground as the shot flies over them.
//
// ─── Why the centre is now the size it is ────────────────────────────────────
//
// This is the number a golfer clubs off, and it was 20pt in a box in a corner,
// with a second box on the opposite corner printing a different number for the
// same thing. On hole 10 of Long Biên's Đường A they read 414 and 417: the
// panel measures to the traced green outline along the approach, and the other
// one measured to the polygon's centroid. Two answers to "how far to the
// middle", three yards apart, on one screen, and neither of them large enough
// to read at arm's length in sun with a glove on.
//
// So there is one answer now and it is the biggest thing on the map. The
// centroid reading is gone; the play-line panel it lived in only appears when
// the golfer has placed a target, which is a different question — "how far to
// there, and how much is left after it".

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14331F).withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _edge(l10n.mapGreenBack, backMeters),
          _centre(context),
          _edge(l10n.mapGreenFront, frontMeters),
        ],
      ),
    );
  }

  /// The number the club is chosen off.
  ///
  /// Sized to be read at arm's length in sunlight, which is the only place
  /// this screen is ever used. The unit rides small beside it rather than
  /// taking a line of its own — a golfer knows whether they are in metres.
  Widget _centre(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${MeasureUnits.displayValue(centreMeters, unit)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          MeasureUnits.suffix(unit),
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Front and back, which qualify the centre rather than compete with it.
  Widget _edge(String label, double metres) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        '$label ${MeasureUnits.format(metres, unit)}',
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
