// Shot Entry Sheet — VSP Mobile App
//
// Bottom sheet for 2-tap shot entry during an active round.
//
// 2-Tap Flow:
//  1. Tap "Start Shot" → captures GPS start location, shows "Shot Active"
//  2. Tap "End Shot" → captures GPS end location, calculates lie/distance
//
// Per Story 10.3 — Slice 2: UI — Shot Entry
//
// UX requirements:
//  - Glanceable: large text, high contrast
//  - One-hand operation
//  - GPS accuracy visible on capture
//  - Offline save indicator
//  - Semantics labels, 44/48pt touch targets

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../application/services/shot_tracking_service.dart';
import '../../../data/services/round_state_service.dart';
import '../../../domain/models/shot.dart';
import '../../../domain/services/lie_detector.dart';
import '../../../domain/value_objects/lat_lng.dart';
import '../widgets/gps_quality_indicator.dart';
import '../widgets/offline_save_indicator.dart';
import '../widgets/shot/club_selector.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Bottom sheet for shot entry with 2-tap flow.
///
/// Usage:
/// ```dart
/// await ShotEntrySheet.show(
///   context,
///   roundId: '...',
///   flightId: '...',
///   playerId: '...',
///   holeNumber: 1,
///   shotNumber: 1,
///   clubs: activeBag.clubs,
///   onShotStarted: (shot) { ... },
///   onShotEnded: (result) { ... },
/// );
/// ```
class ShotEntrySheet extends StatefulWidget {
  /// Round this shot belongs to.
  final String roundId;

  /// Flight this shot belongs to.
  final String flightId;

  /// Player taking the shot.
  final String playerId;

  /// Hole number (1-18).
  final int holeNumber;

  /// Shot number (per-hole sequence).
  final int shotNumber;

  /// Available clubs from active bag.
  final List clubs;

  /// Service for shot tracking.
  final ShotTrackingService trackingService;

  /// Lie detector for auto-detecting lie.
  final LieDetector lieDetector;

  /// Callback when shot is started.
  final void Function(Shot shot)? onShotStarted;

  /// Callback when shot is ended.
  final void Function(ShotEndResult result)? onShotEnded;

  const ShotEntrySheet({
    super.key,
    required this.roundId,
    required this.flightId,
    required this.playerId,
    required this.holeNumber,
    required this.shotNumber,
    required this.clubs,
    required this.trackingService,
    required this.lieDetector,
    this.onShotStarted,
    this.onShotEnded,
  });

  /// Show the shot entry sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required String roundId,
    required String flightId,
    required String playerId,
    required int holeNumber,
    required int shotNumber,
    required List clubs,
    required ShotTrackingService trackingService,
    required LieDetector lieDetector,
    void Function(Shot shot)? onShotStarted,
    void Function(ShotEndResult result)? onShotEnded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ShotEntrySheet(
        roundId: roundId,
        flightId: flightId,
        playerId: playerId,
        holeNumber: holeNumber,
        shotNumber: shotNumber,
        clubs: clubs,
        trackingService: trackingService,
        lieDetector: lieDetector,
        onShotStarted: onShotStarted,
        onShotEnded: onShotEnded,
      ),
    );
  }

  @override
  State<ShotEntrySheet> createState() => _ShotEntrySheetState();
}

class _ShotEntrySheetState extends State<ShotEntrySheet> {
  ShotTrackingState _state = ShotTrackingState.idle;
  Shot? _activeShot;
  String? _selectedClubId;
  String? _errorMessage;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _shotSubscription;

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.trackingService.trackingStateStream.listen((
      state,
    ) {
      setState(() => _state = state);
    });
    _shotSubscription = widget.trackingService.activeShotStream.listen((shot) {
      setState(() => _activeShot = shot);
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _shotSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(theme, colorScheme),
            const SizedBox(height: VspSpacing.md),

            // Shot info
            _buildShotInfo(theme, colorScheme),
            const SizedBox(height: VspSpacing.md),

            // Main action area
            _buildActionArea(theme, colorScheme),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: VspSpacing.sm),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: VspSpacing.md),

            // Cancel button (only when shot is active)
            if (_state == ShotTrackingState.shotActive)
              TextButton(
                onPressed: _cancelShot,
                child: Text(AppLocalizations.of(context).shotCancelShot),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        // Close button
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          tooltip: AppLocalizations.of(context).commonClose,
        ),

        const Spacer(),

        // Shot tracking state
        Text(
          _stateLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _stateColor(colorScheme),
          ),
        ),

        const Spacer(),

        // Offline indicator
        OfflineSaveIndicator(syncState: _syncState),
      ],
    );
  }

  Widget _buildShotInfo(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Hole and shot number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hole ${widget.holeNumber}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  'Shot ${widget.shotNumber}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Club selector
          if (_state == ShotTrackingState.idle)
            _ClubSelectorButton(
              selectedClubId: _selectedClubId,
              clubs: widget.clubs,
              onSelected: (clubId) {
                setState(() => _selectedClubId = clubId);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionArea(ThemeData theme, ColorScheme colorScheme) {
    switch (_state) {
      case ShotTrackingState.idle:
        return _StartShotButton(
          onPressed: _startShot,
          hasClub: _selectedClubId != null,
        );

      case ShotTrackingState.shotActive:
        return _EndShotButton(onPressed: _endShot);

      case ShotTrackingState.persisting:
        return const _PersistingIndicator();

      case ShotTrackingState.persisted:
        return _PersistedIndicator(
          onDismiss: () => Navigator.of(context).pop(),
        );

      case ShotTrackingState.error:
        return _ErrorIndicator(
          onRetry: _startShot,
          message: _errorMessage ?? 'An error occurred',
        );
    }
  }

  String get _stateLabel {
    switch (_state) {
      case ShotTrackingState.idle:
        return 'Ready';
      case ShotTrackingState.shotActive:
        return 'Shot Active';
      case ShotTrackingState.persisting:
        return 'Saving...';
      case ShotTrackingState.persisted:
        return 'Saved';
      case ShotTrackingState.error:
        return 'Error';
    }
  }

  Color _stateColor(ColorScheme colorScheme) {
    switch (_state) {
      case ShotTrackingState.idle:
        return colorScheme.onSurface;
      case ShotTrackingState.shotActive:
        return colorScheme.primary;
      case ShotTrackingState.persisting:
        return colorScheme.tertiary;
      case ShotTrackingState.persisted:
        return Colors.green;
      case ShotTrackingState.error:
        return colorScheme.error;
    }
  }

  RoundSyncState get _syncState {
    switch (_state) {
      case ShotTrackingState.idle:
        return RoundSyncState.synced;
      case ShotTrackingState.shotActive:
        return RoundSyncState.pending;
      case ShotTrackingState.persisting:
        return RoundSyncState.syncing;
      case ShotTrackingState.persisted:
        return RoundSyncState.synced;
      case ShotTrackingState.error:
        return RoundSyncState.failed;
    }
  }

  Future<void> _startShot() async {
    setState(() => _errorMessage = null);

    try {
      final shot = await widget.trackingService.startShot(
        roundId: widget.roundId,
        flightId: widget.flightId,
        playerId: widget.playerId,
        holeNumber: widget.holeNumber,
        shotNumber: widget.shotNumber,
        clubId: _selectedClubId,
      );
      widget.onShotStarted?.call(shot);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to start shot: $e');
    }
  }

  Future<void> _endShot() async {
    setState(() => _errorMessage = null);

    try {
      final result = await widget.trackingService.endShot(
        clubId: _selectedClubId,
        lieDetector: (start, end, accuracy) {
          // Try to detect lie using hole geometry if available
          // For now, use simplified detection
          return widget.lieDetector.detectLieSimplified(
            startLocation: start,
            endLocation: end,
            gpsAccuracyMeters: accuracy,
          );
        },
      );
      widget.onShotEnded?.call(result);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to end shot: $e');
    }
  }

  Future<void> _cancelShot() async {
    await widget.trackingService.cancelActiveShot();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _ClubSelectorButton extends StatelessWidget {
  final String? selectedClubId;
  final List clubs;
  final ValueChanged<String?> onSelected;

  const _ClubSelectorButton({
    required this.selectedClubId,
    required this.clubs,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: selectedClubId != null ? 'Club selected' : 'Select club',
      button: true,
      child: Material(
        color: selectedClubId != null
            ? colorScheme.primaryContainer
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            final club = await ClubSelector.show(context, clubs: clubs.cast());
            if (club != null) {
              onSelected(club.id.toString());
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 80,
              minHeight: VspSpacingSemantic.touchTargetMin,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: VspSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedClubId != null
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.golf_course,
                  size: 18,
                  color: selectedClubId != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  selectedClubId != null ? 'Club OK' : 'Select Club',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selectedClubId != null
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: selectedClubId != null ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartShotButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool hasClub;

  const _StartShotButton({required this.onPressed, required this.hasClub});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: hasClub ? 'Start shot' : 'Select a club first',
      button: true,
      child: SizedBox(
        height: 64,
        child: ElevatedButton(
          onPressed: hasClub ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: colorScheme.surfaceContainerHighest,
            disabledForegroundColor: colorScheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, size: 28),
              const SizedBox(width: VspSpacing.sm),
              Text(
                'Start Shot',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hasClub
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndShotButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EndShotButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context).shotEndShot,
      button: true,
      child: SizedBox(
        height: 64,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_rounded, size: 28),
              const SizedBox(width: VspSpacing.sm),
              Text(
                'End Shot',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersistingIndicator extends StatelessWidget {
  const _PersistingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 64,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: VspSpacing.sm),
            Text(AppLocalizations.of(context).shotSaving, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _PersistedIndicator extends StatelessWidget {
  final VoidCallback onDismiss;

  const _PersistedIndicator({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 64,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: VspSpacing.sm),
            Text(
              'Shot saved!',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorIndicator extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const _ErrorIndicator({required this.onRetry, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              const SizedBox(width: VspSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VspSpacing.sm),
        TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).commonRetry)),
      ],
    );
  }
}
