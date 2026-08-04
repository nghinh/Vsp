// ScoreRowWidget — VSP Mobile App
//
// Single-row display of a hole's score in the scorecard.
// Per Story 5.5 Slice 3: AC-2 per-hole score display with score vs par.
//
// Accessibility: Semantics labels on all score rows.

import 'package:flutter/material.dart';

import '../../domain/score_entry.dart';

/// Widget rendering a single hole score row.
class ScoreRowWidget extends StatelessWidget {
  final ScoreEntry entry;
  final VoidCallback? onTap;

  const ScoreRowWidget({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = entry.relativeToPar;

    // Color coding: under par = green, over par = red, par = neutral
    final diffColor = diff < 0
        ? Colors.green
        : diff > 0
        ? Colors.red
        : theme.colorScheme.onSurface;

    return Semantics(
      label:
          'Hole ${entry.holeNumber}: ${entry.strokes} strokes, ${entry.scoreNotation}',
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
                  'Par ${entry.par}',
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
              // Score vs par
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
