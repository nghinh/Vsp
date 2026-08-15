// Shot Review Screen — VSP Mobile App
//
// Screen for reviewing all shots for a round.
// Shows per-player shot list with edit/delete/merge capabilities.
//
// Per Story 10.3 — Slice 3: UI — Shot Review + Edit
//
// UX requirements:
//  - Per-player shot list
//  - Shot cards with all details
//  - Edit/delete/merge actions
//  - Sync status indicator per shot
//  - Retry action for failed sync

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../application/services/shot_sync_service.dart';
import '../../../domain/models/shot.dart';
import '../../../features/bag/data/bag_dto.dart';
import '../../../domain/models/sync_status.dart';
import '../../widgets/offline_save_indicator.dart';
import '../../widgets/sync_status_badge.dart';
import '../../sheets/shot_edit_sheet.dart';
import '../../widgets/shot/shot_card.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';

/// Screen for reviewing all shots for a round.
///
/// Shows shots grouped by player with edit/delete/merge capabilities.
class ShotReviewScreen extends StatefulWidget {
  /// Round ID.
  final String roundId;

  /// Player ID (current user).
  final String playerId;

  /// All shots for the round.
  final List<Shot> shots;

  /// Available clubs from active bag.
  final List<ClubDTO> clubs;

  /// Shot sync service for mutations.
  final ShotSyncService shotSyncService;

  /// Callback when a shot is edited.
  final void Function(Shot updatedShot)? onShotEdited;

  /// Callback when a shot is deleted.
  final void Function(String shotId)? onShotDeleted;

  /// Callback when shots are merged.
  final void Function(String sourceId, String targetId)? onShotsMerged;

  const ShotReviewScreen({
    super.key,
    required this.roundId,
    required this.playerId,
    required this.shots,
    required this.clubs,
    required this.shotSyncService,
    this.onShotEdited,
    this.onShotDeleted,
    this.onShotsMerged,
  });

  @override
  State<ShotReviewScreen> createState() => _ShotReviewScreenState();
}

class _ShotReviewScreenState extends State<ShotReviewScreen> {
  late List<Shot> _shots;

  @override
  void initState() {
    super.initState();
    _shots = List.from(widget.shots);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Group shots by hole
    final shotsByHole = <int, List<Shot>>{};
    for (final shot in _shots) {
      shotsByHole.putIfAbsent(shot.holeNumber, () => []).add(shot);
    }

    // Sort holes
    final sortedHoles = shotsByHole.keys.toList()..sort();

    // Calculate aggregated sync status
    final aggregatedStatus = _calculateAggregatedStatus(_shots);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).shotReviewTitle),
        centerTitle: true,
        actions: [
          // Sync status
          Padding(
            padding: const EdgeInsets.only(right: VspSpacing.sm),
            child: SyncStatusBadge(status: aggregatedStatus, compact: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header
          _buildSummaryHeader(theme, colorScheme),

          // Shot list
          Expanded(
            child: _shots.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: VspSpacing.md),
                    itemCount: sortedHoles.length,
                    itemBuilder: (context, index) {
                      final holeNumber = sortedHoles[index];
                      final holeShots = shotsByHole[holeNumber]!;
                      return _buildHoleSection(
                        theme,
                        colorScheme,
                        holeNumber,
                        holeShots,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(ThemeData theme, ColorScheme colorScheme) {
    // Calculate stats
    final totalShots = _shots.length;
    // Averaged over the shots that have a distance, not over every shot: a
    // putt with no measurement used to be counted in the divisor and not in
    // the sum, which dragged the average down by however many shots the GPS
    // never resolved.
    final measured = _shots
        .map((s) => s.canonicalDistanceMeters)
        .whereType<double>()
        .toList();
    final avgDistance = measured.isEmpty
        ? 0.0
        : measured.reduce((a, b) => a + b) / measured.length;
    final penaltyCount = _shots.where((s) => s.isPenalty).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: AppLocalizations.of(context).shotTotalShots,
            value: '$totalShots',
            icon: Icons.golf_course,
          ),
          _StatItem(
            label: AppLocalizations.of(context).shotAvgDistance,
            value: context.formatDistance(avgDistance),
            icon: Icons.straighten,
          ),
          _StatItem(
            label: AppLocalizations.of(context).shotPenalties,
            value: '$penaltyCount',
            icon: Icons.warning_amber_rounded,
            isHighlighted: penaltyCount > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildHoleSection(
    ThemeData theme,
    ColorScheme colorScheme,
    int holeNumber,
    List<Shot> shots,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hole header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: VspSpacing.sm,
          ),
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text(
                'Hole $holeNumber',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: VspSpacing.sm),
              Text(
                '${shots.length} shot${shots.length != 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Shot cards
        for (final shot in shots)
          ShotCard(
            shot: shot,
            clubName: _getClubName(shot.clubId),
            onTap: () => _editShot(shot),
            onEdit: () => _editShot(shot),
            onDelete: () => _deleteShot(shot),
            onMerge: _shots.length > 1 ? () => _mergeShot(shot) : null,
            onRetrySync: shot.syncStatus == SyncStatus.failed
                ? () => _retrySync(shot)
                : null,
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.golf_course_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).shotNoneRecorded,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: VspSpacing.xs),
          Text(
            'Start tracking shots during your round',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String? _getClubName(String? clubId) {
    if (clubId == null) return null;
    final club = widget.clubs
        .where((c) => c.id.toString() == clubId)
        .firstOrNull;
    return club?.clubType.displayName;
  }

  SyncStatus _calculateAggregatedStatus(List<Shot> shots) {
    if (shots.isEmpty) return SyncStatus.synced;

    bool hasFailed = false;
    bool hasSyncing = false;
    bool hasPending = false;

    for (final shot in shots) {
      switch (shot.syncStatus) {
        case SyncStatus.failed:
          hasFailed = true;
        case SyncStatus.syncing:
          hasSyncing = true;
        case SyncStatus.pending:
          hasPending = true;
        case SyncStatus.synced:
          break;
      }
    }

    if (hasFailed) return SyncStatus.failed;
    if (hasSyncing) return SyncStatus.syncing;
    if (hasPending) return SyncStatus.pending;
    return SyncStatus.synced;
  }

  Future<void> _editShot(Shot shot) async {
    final result = await ShotEditSheet.show(
      context: context,
      shot: shot,
      clubs: widget.clubs,
      allShots: _shots,
      onSave: (updatedShot) async {
        final result = await widget.shotSyncService.editShot(
          shotId: shot.id,
          clubId: updatedShot.clubId,
          lie: updatedShot.lie,
          result: updatedShot.result,
          distanceYards: updatedShot.distanceYards,
          distanceMeters: updatedShot.distanceMeters,
          conditions: updatedShot.conditions,
          isPenalty: updatedShot.isPenalty,
          isProvisional: updatedShot.isProvisional,
          isMulligan: updatedShot.isMulligan,
          confidence: updatedShot.confidence,
        );
        return result;
      },
      onDelete: (shotId) async {
        await widget.shotSyncService.deleteShot(shotId);
        widget.onShotDeleted?.call(shotId);
      },
      onMerge: (sourceId, targetId) async {
        final result = await widget.shotSyncService.mergeShots(
          sourceShotId: sourceId,
          targetShotId: targetId,
          roundId: widget.roundId,
          playerId: widget.playerId,
        );
        widget.onShotsMerged?.call(sourceId, targetId);
        return result;
      },
    );

    if (result == null) return;

    if (result.wasDeleted) {
      setState(() {
        _shots.removeWhere((s) => s.id == shot.id);
      });
    } else if (result.wasMerged) {
      setState(() {
        // Mark source shot as merged
        final index = _shots.indexWhere((s) => s.id == shot.id);
        if (index >= 0) {
          _shots[index] = _shots[index].copyWith(
            mergedIntoShotId: result.mergedIntoShotId,
          );
        }
      });
    } else if (result.shot != null) {
      setState(() {
        final index = _shots.indexWhere((s) => s.id == result.shot!.id);
        if (index >= 0) {
          _shots[index] = result.shot!;
        }
      });
      widget.onShotEdited?.call(result.shot!);
    }
  }

  Future<void> _deleteShot(Shot shot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).shotDeleteTitle),
        content: Text(
          AppLocalizations.of(context).shotDeleteConfirm(shot.shotNumber, shot.holeNumber),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context).commonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.shotSyncService.deleteShot(shot.id);
    setState(() {
      _shots.removeWhere((s) => s.id == shot.id);
    });
    widget.onShotDeleted?.call(shot.id);
  }

  Future<void> _mergeShot(Shot shot) async {
    // Open merge selector
    final targetShot = await showModalBottomSheet<Shot>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          _MergeShotSelector(currentShotId: shot.id, shots: _shots),
    );

    if (targetShot == null) return;

    final result = await widget.shotSyncService.mergeShots(
      sourceShotId: shot.id,
      targetShotId: targetShot.id,
      roundId: widget.roundId,
      playerId: widget.playerId,
    );

    setState(() {
      final index = _shots.indexWhere((s) => s.id == shot.id);
      if (index >= 0) {
        _shots[index] = _shots[index].copyWith(mergedIntoShotId: targetShot.id);
      }
    });
    widget.onShotsMerged?.call(shot.id, targetShot.id);
  }

  Future<void> _retrySync(Shot shot) async {
    // Reset the shot's sync status and trigger retry
    // The sync worker will pick up pending shots
    setState(() {
      final index = _shots.indexWhere((s) => s.id == shot.id);
      if (index >= 0) {
        _shots[index] = _shots[index].copyWith(syncStatus: SyncStatus.pending);
      }
    });
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlighted;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: isHighlighted
              ? colorScheme.error
              : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isHighlighted ? colorScheme.error : colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MergeShotSelector extends StatelessWidget {
  final String currentShotId;
  final List<Shot> shots;

  const _MergeShotSelector({required this.currentShotId, required this.shots});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter out current shot and already-merged shots
    final eligibleShots = shots
        .where((s) => s.id != currentShotId && s.mergedIntoShotId == null)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(VspSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: VspSpacing.md),

            // Title
            Text(
              'Merge Shot Into',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.sm),
            Text(
              AppLocalizations.of(context).shotMergeHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.md),

            // Shot list
            Expanded(
              child: eligibleShots.isEmpty
                  ? Center(
                      child: Text(
                        'No eligible shots to merge into',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: eligibleShots.length,
                      itemBuilder: (context, index) {
                        final shot = eligibleShots[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              '${shot.shotNumber}',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(AppLocalizations.of(context).shotNumberLabel('${shot.shotNumber}')),
                          subtitle: shot.lie != null
                              ? Text(_lieLabel(shot.lie!))
                              : null,
                          trailing: shot.canonicalDistanceMeters != null
                              ? Text(context.formatDistance(
                                  shot.canonicalDistanceMeters))
                              : null,
                          onTap: () => Navigator.of(context).pop(shot),
                        );
                      },
                    ),
            ),

            const SizedBox(height: VspSpacing.sm),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
          ],
        ),
      ),
    );
  }

  String _lieLabel(ShotLie lie) {
    switch (lie) {
      case ShotLie.teebox:
        return 'Tee box';
      case ShotLie.fairway:
        return 'Fairway';
      case ShotLie.rough:
        return 'Rough';
      case ShotLie.bunker:
        return 'Bunker';
      case ShotLie.water:
        return 'Water';
      case ShotLie.green:
        return 'Green';
      case ShotLie.putt:
        return 'Putting';
      case ShotLie.outOfBounds:
        return 'OB';
      default:
        return lie.name;
    }
  }
}
