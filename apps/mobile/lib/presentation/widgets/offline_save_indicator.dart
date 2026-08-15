// Offline Save Indicator — VSP Mobile App
//
// Widget showing round sync states with non-color-only feedback.
// States: saved (green checkmark), pending (blue clock), syncing (spinner),
// failed (red X with retry).
//
// AC-3: UI immediately confirms offline save state.
// UX §6.4: "Offline states: Saved offline. Sync when online."
// UX §5.2: "Scorecard — Save feedback immediate. Offline saved indicator visible."
// Non-color-only: icon + text label for each state.
// Minimum 44x44pt touch target for retry action on failed state.
//
// Story 5.2: Persist Round Locally — Slice 5 (PERSIST-UI)

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/services/round_state_service.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Semantic color tokens for sync indicator states.

/// Offline save indicator widget for round sync feedback.
///
/// Shows sync state with icon + text label (non-color-only per AC-3).
/// Used on scorecard and round setup screens.
///
/// States:
/// - [RoundSyncState.synced] → green checkmark + "Saved"
/// - [RoundSyncState.pending] → blue clock + "Pending sync"
/// - [RoundSyncState.syncing] → spinner
/// - [RoundSyncState.failed] → red X + "Sync failed" + retry button
class OfflineSaveIndicator extends StatelessWidget {
  /// Current sync state to display.
  final RoundSyncState syncState;

  /// Callback invoked when user taps retry on failed state.
  /// If null, retry is not shown.
  final VoidCallback? onRetry;

  /// Duration to show the saved confirmation before returning to pending.
  /// Only applies when [syncState] is [RoundSyncState.synced] and
  /// [showBriefSavedThenPending] is true.
  final Duration savedConfirmationDuration;

  /// If true, shows "Saved" briefly then returns to "Pending" state
  /// after [savedConfirmationDuration]. Use for post-score feedback.
  final bool showBriefSavedThenPending;

  const OfflineSaveIndicator({
    super.key,
    required this.syncState,
    this.onRetry,
    this.savedConfirmationDuration = const Duration(seconds: 2),
    this.showBriefSavedThenPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;

    // If brief-saved mode, wrap in AnimatedSwitcher.
    if (showBriefSavedThenPending && syncState == RoundSyncState.synced) {
      return _BriefSavedIndicator(
        duration: savedConfirmationDuration,
        brightness: brightness,
      );
    }

    return Semantics(
      label: _semanticLabel(context, syncState),
      child: _buildIndicator(context, brightness),
    );
  }

  String _semanticLabel(BuildContext context, RoundSyncState state) {
    final l10n = AppLocalizations.of(context);
    switch (state) {
      case RoundSyncState.synced:
        return l10n.syncSavedLocally;
      case RoundSyncState.pending:
        return l10n.syncPendingLabel;
      case RoundSyncState.syncing:
        return l10n.syncSyncingLabel;
      case RoundSyncState.failed:
        return l10n.syncFailedTapRetry;
    }
  }

  Widget _buildIndicator(BuildContext context, Brightness brightness) {
    switch (syncState) {
      case RoundSyncState.synced:
        return _SavedState(brightness: brightness);
      case RoundSyncState.pending:
        return _PendingState(brightness: brightness);
      case RoundSyncState.syncing:
        return const _SyncingState();
      case RoundSyncState.failed:
        return _FailedState(onRetry: onRetry);
    }
  }
}

// ---------------------------------------------------------------------------
// State widgets
// ---------------------------------------------------------------------------

/// Green checkmark + "Saved" label.
class _SavedState extends StatelessWidget {
  final Brightness brightness;

  const _SavedState({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final color = VspColorSemantic.of(brightness, VspSemanticColorToken.online);
    return _SyncIndicatorLayout(
      icon: Icons.check_circle,
      iconColor: color,
      label: AppLocalizations.of(context).syncSaved,
      labelColor: color,
    );
  }
}

/// Blue clock + "Pending sync" label.
class _PendingState extends StatelessWidget {
  final Brightness brightness;

  const _PendingState({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final color = VspColorSemantic.of(brightness, VspSemanticColorToken.syncPending);
    return _SyncIndicatorLayout(
      icon: Icons.schedule,
      iconColor: color,
      label: AppLocalizations.of(context).syncPending,
      labelColor: color,
    );
  }
}

/// Circular progress spinner with "Syncing…" label.
class _SyncingState extends StatelessWidget {
  const _SyncingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return _SyncIndicatorLayout(
      icon: null, // spinner replaces icon
      spinnerColor: color,
      label: AppLocalizations.of(context).syncSyncing,
      labelColor: color,
    );
  }
}

/// Red X + "Sync failed" label with retry button.
class _FailedState extends StatelessWidget {
  final VoidCallback? onRetry;

  const _FailedState({this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;
    final color = VspColorSemantic.of(brightness, VspSemanticColorToken.syncFailed);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SyncIndicatorLayout(
          icon: Icons.error,
          iconColor: color,
          label: AppLocalizations.of(context).syncFailed,
          labelColor: color,
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 4),
          // Minimum 44x44pt touch target for retry
          SizedBox(
            width: VspSpacingSemantic.touchTargetMin,
            height: VspSpacingSemantic.touchTargetMin,
            child: IconButton(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: color, size: 20),
              tooltip: AppLocalizations.of(context).syncRetry,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Brief saved confirmation (2s then return to pending)
// ---------------------------------------------------------------------------

/// Shows "Saved" briefly for 2 seconds, then returns to "Pending".
class _BriefSavedIndicator extends StatefulWidget {
  final Duration duration;
  final Brightness brightness;

  const _BriefSavedIndicator({
    required this.duration,
    required this.brightness,
  });

  @override
  State<_BriefSavedIndicator> createState() => _BriefSavedIndicatorState();
}

class _BriefSavedIndicatorState extends State<_BriefSavedIndicator> {
  bool _showSaved = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) {
        setState(() => _showSaved = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSaved) {
      return _PendingState(brightness: widget.brightness);
    }
    return Semantics(
      label: AppLocalizations.of(context).syncSavedLocally,
      child: _SavedState(brightness: widget.brightness),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared layout
// ---------------------------------------------------------------------------

/// Reusable row layout for sync indicator states.
///
/// Uses icon (or spinner) + text label with consistent spacing.
class _SyncIndicatorLayout extends StatelessWidget {
  /// IconData to show, or null if spinner is used instead.
  final IconData? icon;

  /// Color for the icon.
  final Color? iconColor;

  /// Color for the spinner (used when [icon] is null).
  final Color? spinnerColor;

  /// Text label displayed next to the icon/spinner.
  final String label;

  /// Color for the label text.
  final Color labelColor;

  const _SyncIndicatorLayout({
    this.icon,
    this.iconColor,
    this.spinnerColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.xs,
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
            Icon(icon, size: 14, color: iconColor)
          else
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(spinnerColor!),
              ),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
