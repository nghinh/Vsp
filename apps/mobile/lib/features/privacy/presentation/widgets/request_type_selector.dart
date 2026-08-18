// Request Type Selector — VSP Mobile App
//
// Three-tile selector for DATA_EXPORT / ACCOUNT_DELETION / ROUND_DELETION
// with icons and descriptions. Used in the privacy request submission flow.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/privacy_request_dto.dart';

// ─── Request Type Selector ────────────────────────────────────────────────────

/// A three-tile selector for choosing a privacy request type.
class RequestTypeSelector extends StatelessWidget {
  final PrivacyRequestType? selectedType;
  final ValueChanged<PrivacyRequestType> onTypeSelected;
  final bool enabled;

  const RequestTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in PrivacyRequestType.values) ...[
          _RequestTypeTile(
            type: type,
            isSelected: selectedType == type,
            onTap: enabled ? () => onTypeSelected(type) : null,
          ),
          if (type != PrivacyRequestType.values.last)
            const SizedBox(height: VspSpacing.sm),
        ],
      ],
    );
  }
}

class _RequestTypeTile extends StatelessWidget {
  final PrivacyRequestType type;
  final bool isSelected;
  final VoidCallback? onTap;

  const _RequestTypeTile({
    required this.type,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDestructive = type == PrivacyRequestType.accountDeletion;

    return Semantics(
      label: '${type.displayName}: ${type.description}',
      selected: isSelected,
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? (isDestructive
                        ? (colorScheme.brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.error
                              : VspColorLight.destructive)
                        : colorScheme.primary)
                  : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? (isDestructive
                      ? (colorScheme.brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.error
                                : VspColorLight.destructive)
                            .withOpacity(0.05)
                      : colorScheme.primary.withOpacity(0.05))
                : null,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDestructive
                            ? (colorScheme.brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.error
                                  : VspColorLight.destructive)
                            : colorScheme.primary)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForType(type),
                  color: isSelected
                      ? (isDestructive
                            ? colorScheme.onError
                            : colorScheme.onPrimary)
                      : colorScheme.onSurfaceVariant,
                  size: VspIconSize.md,
                ),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDestructive && isSelected
                            ? (colorScheme.brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.error
                                  : VspColorLight.destructive)
                            : null,
                      ),
                    ),
                    const SizedBox(height: VspSpacing.half),
                    Text(
                      type.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: isDestructive
                      ? (colorScheme.brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.error
                            : VspColorLight.destructive)
                      : colorScheme.primary,
                  size: VspIconSize.md,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(PrivacyRequestType type) {
    switch (type) {
      case PrivacyRequestType.dataExport:
        return Icons.download;
      case PrivacyRequestType.accountDeletion:
        return Icons.delete_forever;
      case PrivacyRequestType.roundDeletion:
        return Icons.golf_course;
    }
  }
}

// ─── Semantic Token ───────────────────────────────────────────────────────────

enum _SemanticToken { destructive }
