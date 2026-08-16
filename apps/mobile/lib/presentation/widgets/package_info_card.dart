// Package Info Card — VSP Mobile App
//
// Card showing course package metadata: name, version, size, last updated.
// Used by CourseDownloadScreen to display package summary.
//
// AC-1: shows package size, version, update time.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/core/l10n/relative_time.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../domain/models/course_package_manifest.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

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
                  _unit(manifest.sizeBytes),
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
                    AppLocalizations.of(context).packageUpdateAvailable,
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
                label: AppLocalizations.of(context).packageVersion,
                value: manifest.version,
              ),
              const SizedBox(width: VspSpacing.md),
              _MetaItem(
                icon: Icons.calendar_today,
                label: AppLocalizations.of(context).packageUpdated,
                value: _formatRelativeTime(
                  AppLocalizations.of(context),
                  manifest.effectiveDate,
                ),
              ),
            ],
          ),

          const SizedBox(height: VspSpacing.sm),

          Row(
            children: [
              _MetaItem(
                icon: Icons.layers,
                label: AppLocalizations.of(context).packageFiles,
                value: '${manifest.files.length}',
              ),
              const SizedBox(width: VspSpacing.md),
              _MetaItem(
                icon: Icons.speed,
                label: AppLocalizations.of(context).packageFormat,
                value: manifest.tilesFormat.value,
              ),
            ],
          ),

          if (manifest.dataVersion != null) ...[
            const SizedBox(height: VspSpacing.sm),
            _MetaItem(
              icon: Icons.fingerprint,
              label: AppLocalizations.of(context).packageDataVersion,
              value: manifest.dataVersion!,
            ),
          ],
        ],
      ),
    );
  }

  /// A course package of geometry is kilobytes, not megabytes. Rounded to
  /// MB it read "0.0 MB", which looks exactly like a package that failed to
  /// download — and that is the screen a golfer was staring at.
  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0);
    }
    return (bytes / (1024 * 1024)).toStringAsFixed(1);
  }

  String _unit(int bytes) => bytes < 1024 * 1024 ? 'KB' : 'MB';

  String _formatRelativeTime(AppLocalizations l10n, DateTime date) =>
      RelativeTime.format(l10n, date);
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
