// ScoreRowWidget — VSP Mobile App
//
// Single-row display of a hole's score in the scorecard.
// Per Story 5.5 Slice 3: AC-2 per-hole score display with score vs par.
//
// Accessibility: Semantics labels on all score rows.

import 'package:flutter/material.dart';

import '../../domain/score_entry.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Widget rendering a single hole score row.
class ScoreRowWidget extends StatelessWidget {
  final ScoreEntry entry;
  final VoidCallback? onTap;

  const ScoreRowWidget({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Par 0 is not a par — it is "this device has no card for this hole".
    // Subtracting it would file a made par as "+4" in red, so where the par
    // is unknown the row says nothing about it: strokes, and no verdict.
    final parKnown = entry.par > 0;
    final diff = entry.relativeToPar;

    // Color coding: under par = green, over par = red, par = neutral
    final diffColor = diff < 0
        ? Theme.of(context).colorScheme.tertiary
        : diff > 0
        ? Theme.of(context).colorScheme.error
        : theme.colorScheme.onSurface;

    return Semantics(
      label: AppLocalizations.of(context).scoreRowSemantics(
        '${entry.holeNumber}',
        '${entry.strokes}',
        parKnown ? entry.scoreNotation : '${entry.strokes}',
      ),
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              // Hole number
              SizedBox(
                width: 32,
                child: Text(
                  '${entry.holeNumber}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Par
              SizedBox(
                width: 28,
                child: Text(
                  parKnown
                      ? AppLocalizations.of(context).coursePar('${entry.par}')
                      : '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Strokes
              Expanded(
                child: Text(
                  '${entry.strokes}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Score vs par — only when there is a par to be relative to.
              if (parKnown)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    diff == 0
                        ? 'E'
                        : diff > 0
                        ? '+$diff'
                        : '$diff',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: diffColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Progressive fields
              if (entry.putts != null || entry.penalties != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    _buildProgressiveLabel(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildProgressiveLabel() {
    final parts = <String>[];
    if (entry.putts != null) parts.add('${entry.putts} putts');
    if (entry.penalties != null && entry.penalties! > 0) {
      parts.add('${entry.penalties} penalty');
    }
    return parts.join(' · ');
  }
}
