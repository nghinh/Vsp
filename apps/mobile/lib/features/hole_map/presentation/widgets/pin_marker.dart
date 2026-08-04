// PinMarker — VSP Mobile App
//
// Displays the pin (hole flag) position badge with source indicator.
// Official pins show green badge; estimated pins show amber warning.
// Expired pins show a distinct visual state with warning indicator.
//
// Story 7.3 — Slice 4: PinMarker UI Extension

import 'package:flutter/material.dart';

import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';

/// Badge showing pin position with official/estimated/expired source indicator.
class PinMarker extends StatelessWidget {
  final PinEntity pin;

  const PinMarker({super.key, required this.pin});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _buildSemanticLabel(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pin.isExpired ? Icons.warning_amber : Icons.flag,
              size: 14,
              color: pin.isExpired
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFEA580C),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PIN',
                  style: TextStyle(
                    color: Color(0xFFEA580C),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sourceLabel,
                      style: TextStyle(color: _sourceColor, fontSize: 9),
                    ),
                    if (pin.isExpired) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.error_outline,
                        size: 10,
                        color: Color(0xFFDC2626),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _borderColor {
    if (pin.isExpired) {
      return const Color(0xFFDC2626).withOpacity(0.6);
    }
    return pin.isOfficial
        ? const Color(0xFF22C55E).withOpacity(0.6)
        : const Color(0xFFF97316).withOpacity(0.6);
  }

  Color get _sourceColor {
    if (pin.isExpired) {
      return const Color(0xFFDC2626);
    }
    return pin.isOfficial ? const Color(0xFF22C55E) : const Color(0xFFF97316);
  }

  String get _sourceLabel {
    if (pin.isExpired) return 'Expired';
    return pin.isOfficial ? 'Official' : 'Estimated';
  }

  String _buildSemanticLabel() {
    final parts = <String>['Pin position'];

    if (pin.isExpired) {
      parts.add('expired');
    } else if (pin.isOfficial) {
      parts.add('official');
    } else {
      parts.add('estimated');
    }

    if (pin.confidence != null) {
      parts.add(
        'confidence ${(pin.confidence! * 100).toStringAsFixed(0)} percent',
      );
    }

    if (pin.expiryDate != null && !pin.isExpired) {
      parts.add('expires ${_formatDate(pin.expiryDate!)}');
    }

    if (pin.effectiveDate != null) {
      parts.add('effective ${_formatDate(pin.effectiveDate!)}');
    }

    return parts.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
