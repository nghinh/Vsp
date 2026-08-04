// Course Package Status Chip — VSP Mobile App
//
// Compact chip showing course package status: downloaded, update available, not downloaded.
// Used on course cards in CourseSearchScreen.
//
// AC-1, AC-3: package status display.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

/// Compact chip showing package download status.
class CoursePackageStatusChip extends StatelessWidget {
  /// Status: null = not downloaded, 'downloaded' = offline ready, 'update' = update available
  final String? status;
  final bool compact;

  const CoursePackageStatusChip({super.key, this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;

    if (status == 'update') {
      return _buildChip(
        context,
        label: 'Update',
        icon: Icons.system_update_alt,
        semanticColor: brightness == Brightness.dark
            ? VspColorDark.secondary
            : VspColorLight.secondary,
      );
    }

    if (status == 'downloaded') {
      return _buildChip(
        context,
        label: 'Downloaded',
        icon: Icons.offline_pin,
        semanticColor: brightness == Brightness.dark
            ? VspColorDark.accent
            : VspColorLight.accent,
      );
    }

    // Not downloaded
    return _buildChip(
      context,
      label: 'Download',
      icon: Icons.download,
      semanticColor: brightness == Brightness.dark
          ? VspColorDark.textTertiary
          : VspColorLight.textTertiary,
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color semanticColor,
  }) {
    return Semantics(
      label: 'Course package $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: semanticColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 11 : 13, color: semanticColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: semanticColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SemanticToken {
  courseDownloaded,
  courseUpdateAvailable,
  courseNotDownloaded,
}
