// Download Progress Indicator — VSP Mobile App
//
// Progress bar widget showing download bytes, percent complete, and current file.
// Used by CourseDownloadScreen during active download.
//
// AC-1: shows package size, progress, retry.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../domain/models/download_progress.dart';

/// Progress bar with bytes/percent/file info for active downloads.
class DownloadProgressIndicator extends StatelessWidget {
  final DownloadProgress progress;

  const DownloadProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;
    final colorScheme = theme.colorScheme;

    final percent = progress.percentCompleteInt;
    final downloaded = _formatBytes(progress.downloadedBytes);
    final total = _formatBytes(progress.totalBytes);

    return Semantics(
      label:
          'Downloading ${progress.currentFile ?? "package"}: $percent% complete, $downloaded of $total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File name
          if (progress.currentFile != null)
            Padding(
              padding: const EdgeInsets.only(bottom: VspSpacing.xs),
              child: Text(
                progress.currentFile!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.percentComplete > 0
                  ? progress.percentComplete
                  : null,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                VspColorSemantic.of(brightness, VspSemanticColorToken.syncPending),
              ),
            ),
          ),

          const SizedBox(height: VspSpacing.xs),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // File index
              Text(
                'File ${progress.currentFileIndex + 1} of ${progress.totalFiles}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              // Percent
              Text(
                '$percent%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: VspColorSemantic.syncPending,
                ),
              ),
            ],
          ),

          const SizedBox(height: VspSpacing.half),

          // Bytes row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$downloaded / $total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (progress.retryCount > 0)
                Text(
                  'Retry ${progress.retryCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: brightness == Brightness.dark
                        ? VspColorDark.destructive
                        : VspColorLight.destructive,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

