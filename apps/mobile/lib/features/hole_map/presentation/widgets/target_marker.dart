// TargetMarker — VSP Mobile App
//
// Draggable target marker placed by the golfer for distance reference.
// Displays target position with label.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/features/hole_map/domain/target_entity.dart';

/// Badge showing the user-placed target marker.
class TargetMarker extends StatelessWidget {
  final TargetEntity target;

  const TargetMarker({super.key, required this.target});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Target placed${target.label != null ? ': ${target.label}' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF22D3EE).withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_fixed, size: 14, color: Color(0xFF22D3EE)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TARGET',
                  style: TextStyle(
                    color: Color(0xFF22D3EE),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (target.label != null)
                  Text(
                    target.label!,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
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
}
