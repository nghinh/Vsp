// Shot Edit Sheet — VSP Mobile App
//
// Bottom sheet for editing a shot's details.
// Allows editing club, lie, result, and penalty/provisional/mulligan markers.
//
// Per Story 10.3 — Slice 3: UI — Shot Review + Edit
//
// UX requirements:
//  - Semantics labels for screen readers
//  - 44/48pt touch targets
//  - Delete with confirmation dialog
//  - Merge with shot selection

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../domain/models/shot.dart';
import '../../../features/bag/data/bag_dto.dart';
import '../../../domain/models/sync_status.dart';
import '../widgets/shot/club_selector.dart';
import '../widgets/shot/penalty_toggle.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Result of editing a shot.
class ShotEditResult {
  /// Updated shot (if saved).
  final Shot? shot;

  /// True if shot was deleted.
  final bool wasDeleted;

  /// True if shots were merged.
  final bool wasMerged;

  /// Merged into shot ID (if merged).
  final String? mergedIntoShotId;

  const ShotEditResult({
    this.shot,
    this.wasDeleted = false,
    this.wasMerged = false,
    this.mergedIntoShotId,
  });
}

/// Bottom sheet for editing a shot.
class ShotEditSheet extends StatefulWidget {
  /// The shot to edit.
  final Shot shot;

  /// Available clubs from active bag.
  final List<ClubDTO> clubs;

  /// All shots for the round (for merge selection).
  final List<Shot> allShots;

  /// Callback when shot is saved.
  final Future<Shot> Function(Shot updatedShot)? onSave;

  /// Callback when shot is deleted.
  final Future<void> Function(String shotId)? onDelete;

  /// Callback when shots are merged.
  final Future<Shot> Function(String sourceShotId, String targetShotId)?
  onMerge;

  const ShotEditSheet({
    super.key,
    required this.shot,
    required this.clubs,
    required this.allShots,
    this.onSave,
    this.onDelete,
    this.onMerge,
  });

  /// Show the shot edit sheet as a modal bottom sheet.
  static Future<ShotEditResult?> show({
    required BuildContext context,
    required Shot shot,
    required List<ClubDTO> clubs,
    required List<Shot> allShots,
    Future<Shot> Function(Shot updatedShot)? onSave,
    Future<void> Function(String shotId)? onDelete,
    Future<Shot> Function(String sourceShotId, String targetShotId)? onMerge,
  }) {
    return showModalBottomSheet<ShotEditResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ShotEditSheet(
        shot: shot,
        clubs: clubs,
        allShots: allShots,
        onSave: onSave,
        onDelete: onDelete,
        onMerge: onMerge,
      ),
    );
  }

  @override
  State<ShotEditSheet> createState() => _ShotEditSheetState();
}

class _ShotEditSheetState extends State<ShotEditSheet> {
  late String? _selectedClubId;
  late ShotLie? _selectedLie;
  late ShotResult? _selectedResult;
  late bool _isPenalty;
  late bool _isProvisional;
  late bool _isMulligan;

  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedClubId = widget.shot.clubId;
    _selectedLie = widget.shot.lie;
    _selectedResult = widget.shot.result;
    _isPenalty = widget.shot.isPenalty;
    _isProvisional = widget.shot.isProvisional;
    _isMulligan = widget.shot.isMulligan;
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
              'Edit Shot ${widget.shot.shotNumber}',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.md),

            // Club selector
            _buildClubSelector(theme, colorScheme),
            const SizedBox(height: 12),

            // Lie selector
            _buildLieSelector(theme, colorScheme),
            const SizedBox(height: 12),

            // Result selector
            _buildResultSelector(theme, colorScheme),
            const SizedBox(height: 12),

            // Penalty markers
            Text(
              'Shot Markers',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: VspSpacing.sm),
            PenaltyToggleRow(
              isPenalty: _isPenalty,
              isProvisional: _isProvisional,
              isMulligan: _isMulligan,
              onPenaltyChanged: (v) => setState(() => _isPenalty = v),
              onProvisionalChanged: (v) => setState(() => _isProvisional = v),
              onMulliganChanged: (v) => setState(() => _isMulligan = v),
            ),

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

            // Action buttons
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else
              _buildActions(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildClubSelector(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Club',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: VspSpacing.xs),
        _SelectorButton(
          label: _clubLabel,
          icon: Icons.golf_course,
          onTap: () async {
            final club = await ClubSelector.show(
              context,
              clubs: widget.clubs,
              selectedClub: widget.clubs
                  .where((c) => c.id.toString() == _selectedClubId)
                  .firstOrNull,
            );
            if (club != null) {
              setState(() => _selectedClubId = club.id.toString());
            }
          },
        ),
      ],
    );
  }

  Widget _buildLieSelector(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lie',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: VspSpacing.xs),
        Wrap(
          spacing: VspSpacing.xs,
          runSpacing: VspSpacing.xs,
          children: [
            for (final lie in ShotLie.values)
              _LieChip(
                lie: lie,
                isSelected: _selectedLie == lie,
                onTap: () => setState(() => _selectedLie = lie),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultSelector(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Result',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: VspSpacing.xs),
        Wrap(
          spacing: VspSpacing.xs,
          runSpacing: VspSpacing.xs,
          children: [
            for (final result in ShotResult.values)
              _ResultChip(
                result: result,
                isSelected: _selectedResult == result,
                onTap: () => setState(() => _selectedResult = result),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Save button
        FilledButton(onPressed: _save, child: Text(AppLocalizations.of(context).shotSaveChanges)),
        const SizedBox(height: VspSpacing.sm),

        // Merge and Delete row
        Row(
          children: [
            // Merge button
            if (widget.onMerge != null && widget.allShots.length > 1)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showMergeSelector,
                  icon: const Icon(Icons.merge_type),
                  label: Text(AppLocalizations.of(context).shotMerge),
                ),
              ),
            if (widget.onMerge != null &&
                widget.allShots.length > 1 &&
                widget.onDelete != null)
              const SizedBox(width: VspSpacing.sm),

            // Delete button
            if (widget.onDelete != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _confirmDelete,
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: VspSpacing.sm),

        // Cancel button
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
      ],
    );
  }

  String get _clubLabel {
    if (_selectedClubId == null) return 'Select club';
    final club = widget.clubs
        .where((c) => c.id.toString() == _selectedClubId)
        .firstOrNull;
    return club?.clubType.displayName ?? 'Select club';
  }

  Future<void> _save() async {
    if (widget.onSave == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedShot = widget.shot.copyWith(
        clubId: _selectedClubId,
        lie: _selectedLie,
        result: _selectedResult,
        isPenalty: _isPenalty,
        isProvisional: _isProvisional,
        isMulligan: _isMulligan,
        syncStatus: SyncStatus.pending,
        updatedAt: DateTime.now(),
      );

      final savedShot = await widget.onSave!(updatedShot);
      if (mounted) {
        Navigator.of(context).pop(ShotEditResult(shot: savedShot));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save: $e';
        _isSaving = false;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).shotDeleteTitle),
        content: Text(
          'Are you sure you want to delete shot ${widget.shot.shotNumber}? This action cannot be undone.',
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

    setState(() => _isDeleting = true);

    try {
      await widget.onDelete!(widget.shot.id);
      if (mounted) {
        Navigator.of(context).pop(const ShotEditResult(wasDeleted: true));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to delete: $e';
        _isDeleting = false;
      });
    }
  }

  Future<void> _showMergeSelector() async {
    final targetShot = await showModalBottomSheet<Shot>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _MergeShotSelector(
        currentShotId: widget.shot.id,
        shots: widget.allShots,
      ),
    );

    if (targetShot == null || widget.onMerge == null) return;

    try {
      final mergedShot = await widget.onMerge!(widget.shot.id, targetShot.id);
      if (mounted) {
        Navigator.of(context).pop(
          ShotEditResult(
            wasMerged: true,
            mergedIntoShotId: targetShot.id,
            shot: mergedShot,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to merge: $e');
    }
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _SelectorButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectorButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: VspSpacing.sm),
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LieChip extends StatelessWidget {
  final ShotLie lie;
  final bool isSelected;
  final VoidCallback onTap;

  const _LieChip({
    required this.lie,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context).shotLieLabel(_lieLabel(lie)),
      button: true,
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VspSpacing.sm,
              vertical: VspSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _lieLabel(lie),
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _lieLabel(ShotLie lie) {
    switch (lie) {
      case ShotLie.teebox:
        return 'Tee';
      case ShotLie.fairway:
        return 'Fairway';
      case ShotLie.rough:
        return 'Rough';
      case ShotLie.bunker:
        return 'Bunker';
      case ShotLie.water:
        return 'Water';
      case ShotLie.penalty:
        return 'Penalty';
      case ShotLie.green:
        return 'Green';
      case ShotLie.putt:
        return 'Putt';
      case ShotLie.outOfBounds:
        return 'OB';
      case ShotLie.cartPath:
        return 'Cart Path';
      default:
        return lie.name;
    }
  }
}

class _ResultChip extends StatelessWidget {
  final ShotResult result;
  final bool isSelected;
  final VoidCallback onTap;

  const _ResultChip({
    required this.result,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: AppLocalizations.of(context).shotResultLabel(_resultLabel(result)),
      button: true,
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VspSpacing.sm,
              vertical: VspSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _resultLabel(result),
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resultLabel(ShotResult result) {
    switch (result) {
      case ShotResult.fairwayHit:
        return 'Fwy';
      case ShotResult.greenHit:
        return 'GIR';
      case ShotResult.inBunker:
        return 'Bunker';
      case ShotResult.inWater:
        return 'Water';
      case ShotResult.outOfBounds:
        return 'OB';
      case ShotResult.penalty:
        return 'Penalty';
      case ShotResult.mulligan:
        return 'Mulligan';
      case ShotResult.provisional:
        return 'Prov';
      case ShotResult.scrambleSave:
        return 'Scramble';
      case ShotResult.chipIn:
        return 'Chip';
      case ShotResult.holeOut:
        return 'Hole Out';
      case ShotResult.inTheHole:
        return 'Hole!';
      default:
        return result.name;
    }
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

    // Filter out current shot and merged shots
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
              'Select the shot to merge this shot into. The current shot will be marked as merged.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VspSpacing.md),

            // Shot list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: eligibleShots.length,
                itemBuilder: (context, index) {
                  final shot = eligibleShots[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        '${shot.shotNumber}',
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                    title: Text(AppLocalizations.of(context).shotNumberLabel('${shot.shotNumber}')),
                    subtitle: shot.lie != null
                        ? Text(_lieLabel(shot.lie!))
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
