// Delete Package Dialog — VSP Mobile App
//
// Confirmation dialog for deleting a downloaded course package.
// Explicitly states that rounds and scores are preserved.
//
// AC-2: user can delete packages without deleting round/score data.
// Design: destructive action requires confirmation, explicit preservation messaging.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Confirmation dialog before deleting a downloaded course package.
///
/// AC-2: explicitly states rounds/scores are NOT deleted.
class DeletePackageDialog extends StatelessWidget {
  final String courseName;
  final VoidCallback onConfirm;

  const DeletePackageDialog({
    super.key,
    required this.courseName,
    required this.onConfirm,
  });

  /// Show the delete confirmation dialog.
  static Future<bool> show(
    BuildContext context, {
    required String courseName,
    required VoidCallback onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          DeletePackageDialog(courseName: courseName, onConfirm: onConfirm),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(AppLocalizations.of(context).downloadRemoveTitle, style: theme.textTheme.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will remove "$courseName" maps and data from your device.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),

          // Rounds/scores preservation notice
          Container(
            padding: const EdgeInsets.all(VspSpacing.sm),
            decoration: BoxDecoration(
              color: VspColorSemantic.of(
                colorScheme.brightness,
                VspSemanticColorToken.courseDownloaded,
              ).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: VspColorSemantic.of(
                  colorScheme.brightness,
                  VspSemanticColorToken.courseDownloaded,
                ).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: VspColorSemantic.of(
                    colorScheme.brightness,
                    VspSemanticColorToken.courseDownloaded,
                  ),
                ),
                const SizedBox(width: VspSpacing.sm),
                Expanded(
                  child: Text(
                    'Your rounds and scores will NOT be deleted and will remain available.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: VspColorSemantic.of(
                        colorScheme.brightness,
                        VspSemanticColorToken.courseDownloaded,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        TextButton(
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop(true);
          },
          style: TextButton.styleFrom(
            foregroundColor: VspColorSemantic.of(
              colorScheme.brightness,
              VspSemanticColorToken.syncFailed,
            ),
          ),
          child: const Text(
            'Remove',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

