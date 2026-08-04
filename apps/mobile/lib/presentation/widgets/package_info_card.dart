// Package Info Card — VSP Mobile App
//
// Card showing course package metadata: name, version, size, last updated.
// Used by CourseDownloadScreen to display package summary.
//
// AC-1: shows package size, version, update time.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../domain/models/course_package_manifest.dart';

/// Card displaying package metadata for CourseDownloadScreen.
class PackageInfoCard extends StatelessWidget {
  final CoursePackageManifest manifest;
  final bool updateAvailable;

  const PackageInfoCard({
    super.key,
    required this.manifest,
    this.updateAvailable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: updateAvailable
            ? Border.all(
                color: VspColorSemantic.of(
                  colorScheme.brightness,
                  VspSemanticColorToken.courseUpdateAvailable,
                ),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Package size (large)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatBytes(manifest.sizeBytes),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: VspSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'MB',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (updateAvailable) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VspSpacing.sm,
                    vertical: VspSpacing.half,
                  ),
                  decoration: BoxDecoration(
                    color: VspColorSemantic.of(
                      colorScheme.brightness,
                      VspSemanticColorToken.courseUpdateAvailable,
                    ).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Update available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: VspColorSemantic.of(
                        colorScheme.brightness,
                        VspSemanticColorToken.courseUpdateAvailable,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Metadata grid
          Row(
            children: [
              _MetaItem(
                icon: Icons.verified,
                label: 'Version',
                value: manifest.version,
              ),
              const SizedBox(width: VspSpacing.md),
              _MetaItem(
                icon: Icons.calendar_today,
                label: 'Updated',
                value: _formatRelativeTime(manifest.effectiveDate),
              ),
            ],
          ),

          const SizedBox(height: VspSpacing.sm),

          Row(
            children: [
              _MetaItem(
                icon: Icons.layers,
                label: 'Files',
                value: '${manifest.files.length}',
              ),
              const SizedBox(width: VspSpacing.md),
              _MetaItem(
                icon: Icons.speed,
                label: 'Format',
                value: manifest.tilesFormat.value,
              ),
            ],
          ),

          if (manifest.dataVersion != null) ...[
            const SizedBox(height: VspSpacing.sm),
            _MetaItem(
              icon: Icons.fingerprint,
              label: 'Data version',
              value: manifest.dataVersion!,
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    return mb.toStringAsFixed(1);
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) return 'Just now';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

