// Format Selector — VSP Mobile App
//
// Format and mode selection pills for round setup.
// Casual / Practice / Tournament format toggle.
// Mode selector (Stroke Play unlocked, others locked with lock icon).
//
// Design: ux-spec §4, §5.2 — pill toggle, 44pt touch targets.
//
// Story 5.1 — Slice B: Round Setup UI Screen

import 'package:flutter/material.dart';

import '../../../../domain/models/round_format.dart';
import '../../../../domain/models/round_mode.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Format selector with Casual / Practice / Tournament pill toggle.
class FormatSelector extends StatelessWidget {
  final RoundFormat selectedFormat;
  final ValueChanged<RoundFormat> onFormatChanged;

  const FormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).roundSetupFormat,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: RoundFormat.values.map((format) {
            final isSelected = format == selectedFormat;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: format != RoundFormat.values.last ? 8 : 0,
                ),
                child: _FormatPill(
                  label: _formatLabel(context, format),
                  isSelected: isSelected,
                  onTap: () => onFormatChanged(format),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FormatPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mode selector showing Stroke Play (unlocked) and Stableford (locked).
class ModeSelector extends StatelessWidget {
  final RoundMode selectedMode;
  final ValueChanged<RoundMode> onModeChanged;

  const ModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).roundSetupScoringMode,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: RoundMode.values.map((mode) {
            final isSelected = mode == selectedMode;
            final isUnlocked = mode.isUnlocked;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: mode != RoundMode.values.last ? 8 : 0,
                ),
                child: _ModePill(
                  label: _modeLabel(context, mode),
                  isSelected: isSelected,
                  isUnlocked: isUnlocked,
                  onTap: isUnlocked ? () => onModeChanged(mode) : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const _ModePill({
    required this.label,
    required this.isSelected,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: isUnlocked ? label : '$label (locked)',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : isUnlocked
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : isUnlocked
                  ? colorScheme.outline.withOpacity(0.3)
                  : colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isUnlocked) ...[
                Icon(
                  Icons.lock,
                  size: 14,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : isUnlocked
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurfaceVariant.withOpacity(0.5),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Localised names for the round format and scoring chips.
///
/// The enums own an English `label` for logs and wire values; a Vietnamese
/// golfer choosing between "Casual" and "Tournament" on their own app should
/// not have to read either. Kept here rather than on the enum so the domain
/// layer stays free of BuildContext.
String _formatLabel(BuildContext context, RoundFormat format) {
  final l10n = AppLocalizations.of(context);
  return switch (format) {
    RoundFormat.casual => l10n.roundFormatCasual,
    RoundFormat.practice => l10n.roundFormatPractice,
    RoundFormat.tournament => l10n.roundFormatTournament,
  };
}

String _modeLabel(BuildContext context, RoundMode mode) {
  final l10n = AppLocalizations.of(context);
  return switch (mode) {
    RoundMode.strokePlay => l10n.scoringStrokePlay,
    // Stableford is the term Vietnamese golfers use; the translation is the
    // same word, and pretending otherwise would invent a name nobody says.
    RoundMode.stableford => l10n.scoringStableford,
  };
}
