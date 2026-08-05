// Update Bottom Sheet — VSP Mobile App
//
// Bottom sheet for confirming and managing incremental package updates.
// Shows delta summary (files/size), Update Now (Wi-Fi), and Later actions.
//
// Story 4.4 INC-MOBILE-UI: update UX for incremental updates.
// Design: ux-spec §5.2 — one-hand/two-tap, glanceable states.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../domain/models/package_delta.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Bottom sheet shown when an incremental update is available.
///
/// Shows:
/// - Delta summary: files to update, files to remove, size
/// - Update Now button (respects Wi-Fi preference)
/// - Later button to defer
///
/// Returns true if user chose to update, false if deferred.
Future<bool> showUpdateBottomSheet(
  BuildContext context, {
  required PackageDelta delta,
  required String currentVersion,
  required String newVersion,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _UpdateBottomSheet(
      delta: delta,
      currentVersion: currentVersion,
      newVersion: newVersion,
    ),
  );
  return result ?? false;
}

class _UpdateBottomSheet extends StatelessWidget {
  final PackageDelta delta;
  final String currentVersion;
  final String newVersion;

  const _UpdateBottomSheet({
    required this.delta,
    required this.currentVersion,
    required this.newVersion,
  });

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
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: VspSpacing.md),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(VspSpacing.sm),
                  decoration: BoxDecoration(
                    color: VspColorSemantic.of(
                      colorScheme.brightness,
                      VspSemanticColorToken.courseUpdateAvailable,
                    ).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.system_update_alt,
                    color: VspColorSemantic.of(
                      colorScheme.brightness,
                      VspSemanticColorToken.courseUpdateAvailable,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Available',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'v$currentVersion → v$newVersion',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: VspSpacing.md),

            // Delta summary card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _DeltaRow(
                    icon: Icons.download,
                    label: AppLocalizations.of(context).updateFilesToUpdate,
                    value: '${delta.toDownload.length}',
                    color: colorScheme.primary,
                  ),
                  if (delta.toDelete.isNotEmpty) ...[
                    const SizedBox(height: VspSpacing.sm),
                    _DeltaRow(
                      icon: Icons.delete_outline,
                      label: AppLocalizations.of(context).updateFilesToRemove,
                      value: '${delta.toDelete.length}',
                      color: colorScheme.error,
                    ),
                  ],
                  if (delta.unchangedCount > 0) ...[
                    const SizedBox(height: VspSpacing.sm),
                    _DeltaRow(
                      icon: Icons.check_circle_outline,
                      label: AppLocalizations.of(context).updateUnchanged,
                      value: '${delta.unchangedCount}',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                  const Divider(height: VspSpacing.md),
                  _DeltaRow(
                    icon: Icons.storage,
                    label: AppLocalizations.of(context).updateDownloadSize,
                    value: _formatBytes(delta.totalDownloadBytes),
                    color: colorScheme.primary,
                    isBold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: VspSpacing.md),

            // Wi-Fi notice
            Row(
              children: [
                Icon(Icons.wifi, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: VspSpacing.xs),
                Text(
                  'Updates require internet connection',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: VspSpacing.md),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context).updateLater),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context).updateNow),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _DeltaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _DeltaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: VspSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w600 : null,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

