// RestrictionBadge — VSP Mobile App
//
// Small pill/badge showing that a feature is restricted in tournament mode.
// Includes an info icon that expands to show the restriction reason.
//
// Per UX spec §5.2: restricted controls hidden or disabled with explanation.
// Per UX-A11: accessibility — screen reader, non-color-only, ≥44pt targets.
//
// Story 7.4 — Slice D: Restricted Feature UI

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:flutter/semantics.dart';

/// A small pill badge indicating a feature is restricted in tournament mode.
///
/// Shows:
/// - "Tournament restricted" label
/// - Info icon that expands to show [restrictionReason]
///
/// **Accessibility:**
/// - Semantics label includes the restriction reason for screen readers
/// - Not color-only: uses icon + text + tooltip
/// - Touch target ≥44pt
class RestrictionBadge extends StatelessWidget {
  /// The reason why the feature is restricted.
  /// Used in tooltip and screen reader label.
  final String restrictionReason;

  /// Optional override for the display label.
  /// Defaults to "Tournament restricted".
  final String? label;

  const RestrictionBadge({
    super.key,
    required this.restrictionReason,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    const displayLabel = 'Tournament restricted';

    return Semantics(
      label: '$displayLabel: $restrictionReason',
      tooltip: restrictionReason,
      child: Tooltip(
        message: restrictionReason,
        preferBelow: true,
        waitDuration: const Duration(milliseconds: 300),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0), // Light amber — not color-only
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(
                0xFFFF9800,
              ), // Orange — visible in deuteranopia
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_rounded,
                size: 14,
                color: Color(0xFFE65100), // Dark orange — WCAG contrast
              ),
              const SizedBox(width: 4),
              Text(
                label ?? displayLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.info_outline,
                size: 12,
                color: Color(0xFFE65100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
