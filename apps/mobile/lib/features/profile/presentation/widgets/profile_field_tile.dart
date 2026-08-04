// Profile Field Tile — VSP Mobile App
//
// Reusable tile for one editable profile field.
// Shows label, current value, edit icon, and validation error.
//
// Accessibility per ux-spec.md §10:
// - Screen reader reads field name + value
// - 44pt minimum touch target
// - Non-color-only status

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

/// A single editable profile field row.
class ProfileFieldTile extends StatelessWidget {
  final String label;
  final String? value;
  final String? errorText;
  final bool isLoading;
  final VoidCallback? onTap;

  const ProfileFieldTile({
    super.key,
    required this.label,
    this.value,
    this.errorText,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasError = errorText != null && errorText!.isNotEmpty;

    return Semantics(
      label: '$label: ${value ?? 'not set'}',
      button: true,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasError ? colorScheme.error : colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: VspSpacing.half),
                    if (isLoading)
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    else
                      Text(
                        value ?? '—',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: hasError
                              ? colorScheme.error
                              : colorScheme.onSurface,
                        ),
                      ),
                    if (hasError) ...[
                      const SizedBox(height: VspSpacing.half),
                      Text(
                        errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.edit,
                size: VspIconSize.sm,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
