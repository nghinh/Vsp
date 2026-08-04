// Skill Level Picker — VSP Mobile App
//
// Dropdown picker for skill level (BEGINNER / INTERMEDIATE / ADVANCED / PRO).

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/profile_dto.dart';

/// Skill level dropdown picker.
class SkillLevelPicker extends StatelessWidget {
  final SkillLevel selectedLevel;
  final ValueChanged<SkillLevel> onChanged;

  const SkillLevelPicker({
    super.key,
    required this.selectedLevel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: 'Skill level, currently ${selectedLevel.displayName}',
      button: true,
      child: InkWell(
        onTap: () => _showPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill Level',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: VspSpacing.half),
                    Text(
                      selectedLevel.displayName,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _SkillLevelSheet(
        selectedLevel: selectedLevel,
        onChanged: (level) {
          onChanged(level);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _SkillLevelSheet extends StatelessWidget {
  final SkillLevel selectedLevel;
  final ValueChanged<SkillLevel> onChanged;

  const _SkillLevelSheet({
    required this.selectedLevel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(VspSpacingSemantic.gutterMobile),
            child: Text(
              'Select Skill Level',
              style: theme.textTheme.titleMedium,
            ),
          ),
          ...SkillLevel.values.map((level) {
            final isSelected = level == selectedLevel;
            return ListTile(
              title: Text(level.displayName),
              trailing: isSelected
                  ? Icon(Icons.check, color: colorScheme.primary)
                  : null,
              onTap: () => onChanged(level),
            );
          }),
          const SizedBox(height: VspSpacing.md),
        ],
      ),
    );
  }
}
