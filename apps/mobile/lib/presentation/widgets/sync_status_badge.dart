// SyncStatusBadge — VSP Mobile App
//
// Persistent sync status indicator for the scorecard.
//
// States:
//   pending  → amber clock + "Saved offline"
//   syncing  → blue spinner + "Syncing…"
//   synced   → green checkmark + "Synced"
//   failed   → red warning + "Sync failed" + retry InkWell
//
// Non-color-only: icon + text label always present (UX §10 / UX-DR5).
// Touch target ≥ 48dp on failed retry action.
// Accessibility: Semantics wrapper, respects reducedMotion.
//
// Story 5.4: Synchronize Round Idempotently — Slice 4

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../domain/models/sync_status.dart';

/// Semantic color tokens for sync badge states.

/// A badge widget showing the round-level aggregated sync status.
///
/// Placed in the scorecard bottom bar per story 5.4 AC-3.
/// Uses icon + text (non-color-only), 48dp touch target on retry.
class SyncStatusBadge extends StatelessWidget {
  /// Current aggregated sync status.
  final SyncStatus status;

  /// Called when user taps the retry action on failed state.
  final VoidCallback? onRetry;

  /// Whether to use a compact layout (for inline use).
  final bool compact;

  const SyncStatusBadge({
    super.key,
    required this.status,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;

    // Respect reducedMotion — use static icon instead of spinner.
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: status.accessibilityLabel,
      child: _buildBadge(context, brightness, reducedMotion),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    Brightness brightness,
    bool reducedMotion,
  ) {
    switch (status) {
      case SyncStatus.pending:
        return _PendingBadge(brightness: brightness, compact: compact);
      case SyncStatus.syncing:
        return _SyncingBadge(
          brightness: brightness,
          compact: compact,
          reducedMotion: reducedMotion,
        );
      case SyncStatus.synced:
        return _SyncedBadge(brightness: brightness, compact: compact);
      case SyncStatus.failed:
        return _FailedBadge(
          brightness: brightness,
          compact: compact,
          onRetry: onRetry,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// State widgets
// ---------------------------------------------------------------------------

/// Amber clock + "Saved offline" label.
class _PendingBadge extends StatelessWidget {
  final Brightness brightness;
  final bool compact;

  const _PendingBadge({required this.brightness, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = VspColorSemantic.of(
      brightness,
      VspSemanticColorToken.estimated,
    );
    return _SyncBadgeLayout(
      icon: Icons.schedule,
      iconColor: color,
      label: 'Saved offline',
      labelColor: color,
      compact: compact,
    );
  }
}

/// Blue spinner (or static icon if reducedMotion) + "Syncing…" label.
class _SyncingBadge extends StatelessWidget {
  final Brightness brightness;
  final bool compact;
  final bool reducedMotion;

  const _SyncingBadge({
    required this.brightness,
    this.compact = false,
    this.reducedMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = VspColorSemantic.of(
      brightness,
      VspSemanticColorToken.syncPending,
    );
    return _SyncBadgeLayout(
      icon: reducedMotion ? Icons.cloud_upload : null,
      iconColor: reducedMotion ? color : null,
      spinnerColor: reducedMotion ? null : color,
      label: 'Syncing…',
      labelColor: color,
      compact: compact,
    );
  }
}

/// Green checkmark + "Synced" label.
class _SyncedBadge extends StatelessWidget {
  final Brightness brightness;
  final bool compact;

  const _SyncedBadge({required this.brightness, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = VspColorSemantic.of(
      brightness,
      VspSemanticColorToken.online,
    );
    return _SyncBadgeLayout(
      icon: Icons.check_circle,
      iconColor: color,
      label: 'Synced',
      labelColor: color,
      compact: compact,
    );
  }
}

/// Red warning + "Sync failed" label + retry InkWell (≥ 48dp).
class _FailedBadge extends StatelessWidget {
  final Brightness brightness;
  final bool compact;
  final VoidCallback? onRetry;

  const _FailedBadge({
    required this.brightness,
    this.compact = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final color = VspColorSemantic.of(
      brightness,
      VspSemanticColorToken.syncFailed,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SyncBadgeLayout(
          icon: Icons.warning,
          iconColor: color,
          label: 'Sync failed',
          labelColor: color,
          compact: compact,
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 4),
          // Minimum 48dp touch target per UX §10.
          SizedBox(
            width: VspSpacingSemantic.touchTargetMin,
            height: VspSpacingSemantic.touchTargetMin,
            child: InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(VspSpacing.xs),
              child: Icon(Icons.refresh, color: color, size: compact ? 16 : 20),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared layout
// ---------------------------------------------------------------------------

/// Reusable row layout for sync badge states.
///
/// Uses icon (or spinner) + text label with consistent spacing and
/// background pill decoration.
class _SyncBadgeLayout extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? spinnerColor;
  final String label;
  final Color labelColor;
  final bool compact;

  const _SyncBadgeLayout({
    this.icon,
    this.iconColor,
    this.spinnerColor,
    required this.label,
    required this.labelColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : VspSpacing.sm,
        vertical: compact ? VspSpacing.half : VspSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: labelColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: labelColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: compact ? 12 : 14, color: iconColor)
          else
            SizedBox(
              width: compact ? 12 : 14,
              height: compact ? 12 : 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(spinnerColor!),
              ),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
