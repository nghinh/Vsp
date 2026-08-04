// Hole Picker — VSP Mobile App
//
// Start hole selection widget with auto-suggest and manual override.
// Auto-suggests hole 1 (AM) or hole 10 (PM) based on time of day.
// Manual override shows a hole picker (1-18, front 9, back 9).
//
// Design: ux-spec §4, §5.2 — 44pt touch targets, accessible labels.
//
// Story 5.1 — Slice B: Round Setup UI Screen

import 'package:flutter/material.dart';

/// Hole picker for starting hole selection.
class HolePicker extends StatelessWidget {
  final int selectedHole;
  final String? holes; // 'front9' or 'back9' for 9-hole start
  final ValueChanged<int> onHoleChanged;
  final ValueChanged<String?>? onHolesChanged;
  final int suggestedHole;

  const HolePicker({
    super.key,
    required this.selectedHole,
    this.holes,
    required this.onHoleChanged,
    this.onHolesChanged,
    required this.suggestedHole,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start Hole',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Auto-suggested hole chip
        if (selectedHole == suggestedHole && holes == null)
          _SuggestionChip(
            label: 'Suggested: Hole $suggestedHole',
            subtitle: suggestedHole == 1 ? 'Morning round' : 'Afternoon round',
            icon: Icons.schedule,
            onTap: () => _showHolePicker(context),
          )
        else
          _SelectedHoleChip(
            hole: selectedHole,
            holes: holes,
            onTap: () => _showHolePicker(context),
          ),
      ],
    );
  }

  void _showHolePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _HolePickerSheet(
        selectedHole: selectedHole,
        holes: holes,
        suggestedHole: suggestedHole,
        onHoleChanged: onHoleChanged,
        onHolesChanged: onHolesChanged,
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '$label${subtitle != null ? ', $subtitle' : ''}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.edit, color: colorScheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedHoleChip extends StatelessWidget {
  final int hole;
  final String? holes;
  final VoidCallback onTap;

  const _SelectedHoleChip({
    required this.hole,
    this.holes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String label;
    if (holes == 'front9') {
      label = 'Holes 1-9 (Front 9)';
    } else if (holes == 'back9') {
      label = 'Holes 10-18 (Back 9)';
    } else {
      label = 'Hole $hole';
    }

    return Semantics(
      label: 'Selected: $label. Tap to change.',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.flag, color: colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.edit, color: colorScheme.onSurfaceVariant, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _HolePickerSheet extends StatefulWidget {
  final int selectedHole;
  final String? holes;
  final int suggestedHole;
  final ValueChanged<int> onHoleChanged;
  final ValueChanged<String?>? onHolesChanged;

  const _HolePickerSheet({
    required this.selectedHole,
    this.holes,
    required this.suggestedHole,
    required this.onHoleChanged,
    this.onHolesChanged,
  });

  @override
  State<_HolePickerSheet> createState() => _HolePickerSheetState();
}

class _HolePickerSheetState extends State<_HolePickerSheet> {
  late int _selectedHole;
  late String? _holes;

  @override
  void initState() {
    super.initState();
    _selectedHole = widget.selectedHole;
    _holes = widget.holes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Select Start Hole',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // 9-hole options
            Text(
              '9-Hole Rounds',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _HoleOption(
                    label: 'Front 9',
                    holes: 'Holes 1-9',
                    isSelected: _holes == 'front9',
                    onTap: () {
                      setState(() {
                        _holes = 'front9';
                        _selectedHole = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HoleOption(
                    label: 'Back 9',
                    holes: 'Holes 10-18',
                    isSelected: _holes == 'back9',
                    onTap: () {
                      setState(() {
                        _holes = 'back9';
                        _selectedHole = 10;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 18-hole options
            Text(
              '18-Hole Rounds',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: 18,
                itemBuilder: (context, index) {
                  final hole = index + 1;
                  return _HoleNumberButton(
                    hole: hole,
                    isSelected: _holes == null && _selectedHole == hole,
                    isSuggested: hole == widget.suggestedHole && _holes == null,
                    onTap: () {
                      setState(() {
                        _holes = null;
                        _selectedHole = hole;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onHoleChanged(_selectedHole);
                  widget.onHolesChanged?.call(_holes);
                  Navigator.pop(context);
                },
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoleOption extends StatelessWidget {
  final String label;
  final String holes;
  final bool isSelected;
  final VoidCallback onTap;

  const _HoleOption({
    required this.label,
    required this.holes,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '$label, $holes',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.golf_course,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                holes,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoleNumberButton extends StatelessWidget {
  final int hole;
  final bool isSelected;
  final bool isSuggested;
  final VoidCallback onTap;

  const _HoleNumberButton({
    required this.hole,
    required this.isSelected,
    required this.isSuggested,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: 'Hole $hole${isSuggested ? ', suggested' : ''}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : isSuggested
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : isSuggested
                  ? colorScheme.primary.withOpacity(0.5)
                  : colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$hole',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : isSuggested
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSuggested)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.schedule,
                    size: 10,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
