// Round Picker for Deletion — VSP Mobile App
//
// Bottom sheet picker for selecting a round to delete.
// Shows list of the golfer's rounds with course name, date, and score.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/privacy_request_dto.dart';
import '../../data/privacy_repository.dart';

// ─── Round Picker ─────────────────────────────────────────────────────────────

/// Shows a bottom sheet with a list of rounds for the golfer to select one
/// for deletion. Returns the selected [RoundSummaryDTO] or null if cancelled.
Future<RoundSummaryDTO?> showRoundPickerForDeletion(
  BuildContext context, {
  required PrivacyRepository repository,
}) async {
  return await showModalBottomSheet<RoundSummaryDTO>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _RoundPickerSheet(repository: repository),
  );
}

class _RoundPickerSheet extends StatefulWidget {
  final PrivacyRepository repository;

  const _RoundPickerSheet({required this.repository});

  @override
  State<_RoundPickerSheet> createState() => _RoundPickerSheetState();
}

class _RoundPickerSheetState extends State<_RoundPickerSheet> {
  List<RoundSummaryDTO> _rounds = [];
  bool _isLoading = true;
  String? _error;
  RoundSummaryDTO? _selectedRound;

  @override
  void initState() {
    super.initState();
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rounds = await widget.repository.getMyRounds();
      setState(() {
        _rounds = rounds;
        _isLoading = false;
      });
    } catch (ex) {
      setState(() {
        _error = 'Failed to load rounds. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: VspSpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(VspSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Round to Delete',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(child: _buildContent(scrollController)),

            // Confirm button
            if (_selectedRound != null)
              Container(
                padding: EdgeInsets.only(
                  left: VspSpacing.md,
                  right: VspSpacing.md,
                  bottom: VspSpacing.md + MediaQuery.of(context).padding.bottom,
                  top: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: VspButton(
                    label: 'Select Round',
                    onPressed: () => Navigator.of(context).pop(_selectedRound),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VspSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: VspSpacing.md),
              VspButton(
                label: 'Retry',
                variant: VspButtonVariant.secondary,
                icon: Icons.refresh,
                onPressed: _loadRounds,
              ),
            ],
          ),
        ),
      );
    }

    if (_rounds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VspSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.golf_course,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No Rounds Found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: VspSpacing.sm),
              Text(
                'You haven\'t played any rounds yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: 12,
      ),
      itemCount: _rounds.length,
      separatorBuilder: (_, __) => const SizedBox(height: VspSpacing.sm),
      itemBuilder: (context, index) {
        final round = _rounds[index];
        final isSelected = _selectedRound?.id == round.id;

        return Semantics(
          label:
              '${round.displayLabel}, ${isSelected ? "selected" : "not selected"}',
          selected: isSelected,
          button: true,
          child: InkWell(
            onTap: () => setState(() => _selectedRound = round),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                    : null,
              ),
              child: Row(
                children: [
                  // Golf icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.golf_course,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: VspIconSize.sm,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Round info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          round.courseName ?? 'Unknown Course',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          round.displayLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Selection indicator
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: VspIconSize.md,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
