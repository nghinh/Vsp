// Play line panel — VSP Mobile App
//
// The numbers on the line the golfer is playing along: how far to the flag,
// or — once a target is placed — how far to the target and how much is left
// after it. TAG Heuer writes these on the line itself; this map cannot,
// because a map symbol needs a glyph endpoint and this one has to draw on a
// course with no signal. So the line is on the map and the numbers are here.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

class PlayLinePanel extends StatelessWidget {
  const PlayLinePanel({
    super.key,
    required this.toTarget,
    required this.toPin,
  });

  /// Distance to the target the golfer placed, already formatted. Null when
  /// they have not placed one.
  final String? toTarget;

  /// Distance to the flag — from the target where there is one, from the
  /// golfer otherwise.
  final String toPin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const Key('play_line_panel'),
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
          if (toTarget != null) ...[
            _Row(label: l10n.mapToTarget, value: toTarget!),
            const SizedBox(height: 2),
            _Row(label: l10n.mapTargetToPin, value: toPin),
          ] else
            _Row(label: l10n.mapToPin, value: toPin),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF8FAFC),
            fontFamily: 'Fira Code',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
