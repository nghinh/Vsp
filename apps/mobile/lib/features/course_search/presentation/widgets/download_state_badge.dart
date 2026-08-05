// Download State Badge — VSP Mobile App
//
// Badge showing download state: downloaded, update available, not downloaded.
//
// Design: ux-spec §4.2 + DESIGN.md §Components
// - Downloaded: green check + "Downloaded"
// - Update available: amber + "Update"
// - Not downloaded: grey + "Download"

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Download state of a course package.
enum DownloadState {
  /// Course is downloaded and ready offline.
  downloaded,

  /// Course has a newer package available.
  updateAvailable,

  /// Course is not downloaded.
  notDownloaded,

  /// Download is in progress (with progress 0-1).
  downloading,
}

/// Download state badge — shows current download state with color + icon.
class DownloadStateBadge extends StatelessWidget {
  final DownloadState state;
  final double? progress; // 0.0 to 1.0 for downloading state
  final bool compact;

  const DownloadStateBadge({
    super.key,
    required this.state,
    this.progress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;

    final config = _resolveConfig(context, brightness);

    if (state == DownloadState.downloading) {
      return _buildDownloading(context, config, theme);
    }

    return _buildPill(context, config, theme);
  }

  _BadgeConfig _resolveConfig(BuildContext context, Brightness brightness) {
    switch (state) {
      case DownloadState.downloaded:
        return _BadgeConfig(
          label: AppLocalizations.of(context).downloadDownloaded,
          icon: Icons.check_circle,
          // Tinted background so the accent label/icon stay legible; a solid
          // accent fill matched the text color and rendered the pill blank.
          backgroundColor: brightness == Brightness.dark
              ? VspColorDark.accent.withOpacity(0.16)
              : VspColorLight.accent.withOpacity(0.12),
          textColor: brightness == Brightness.dark
              ? VspColorDark.accent
              : VspColorLight.accent,
          iconColor: brightness == Brightness.dark
              ? VspColorDark.accent
              : VspColorLight.accent,
        );

      case DownloadState.updateAvailable:
        return _BadgeConfig(
          label: AppLocalizations.of(context).downloadUpdate,
          icon: Icons.system_update_alt,
          // Tinted background so the secondary label/icon stay legible; a solid
          // secondary fill matched the text color and rendered the pill blank.
          backgroundColor: brightness == Brightness.dark
              ? VspColorDark.secondary.withOpacity(0.16)
              : VspColorLight.secondary.withOpacity(0.12),
          textColor: brightness == Brightness.dark
              ? VspColorDark.secondary
              : VspColorLight.secondary,
          iconColor: brightness == Brightness.dark
              ? VspColorDark.secondary
              : VspColorLight.secondary,
        );

      case DownloadState.notDownloaded:
        return _BadgeConfig(
          label: AppLocalizations.of(context).downloadDownload,
          icon: Icons.download,
          backgroundColor: Colors.transparent,
          textColor: brightness == Brightness.dark
              ? VspColorDark.textTertiary
              : VspColorLight.textTertiary,
          iconColor: brightness == Brightness.dark
              ? VspColorDark.textTertiary
              : VspColorLight.textTertiary,
        );

      case DownloadState.downloading:
        return _BadgeConfig(
          label: AppLocalizations.of(context).downloadDownloading,
          icon: Icons.downloading,
          backgroundColor: VspColorSemantic.syncPending.withOpacity(0.12),
          textColor: VspColorSemantic.syncPending,
          iconColor: VspColorSemantic.syncPending,
        );
    }
  }

  Widget _buildPill(
    BuildContext context,
    _BadgeConfig config,
    ThemeData theme,
  ) {
    return Semantics(
      label: AppLocalizations.of(context).downloadStatusLabel(config.label.toLowerCase()),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, size: compact ? 11 : 13, color: config.iconColor),
            const SizedBox(width: 4),
            Text(
              config.label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: config.textColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloading(
    BuildContext context,
    _BadgeConfig config,
    ThemeData theme,
  ) {
    final progressValue = (progress ?? 0.0).clamp(0.0, 1.0);

    return Semantics(
      label: AppLocalizations.of(context).downloadProgressLabel('${(progressValue * 100).round()}'),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 11 : 13,
              height: compact ? 11 : 13,
              child: CircularProgressIndicator(
                value: progressValue > 0 ? progressValue : null,
                strokeWidth: 2,
                color: config.iconColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              progressValue > 0
                  ? '${(progressValue * 100).round()}%'
                  : AppLocalizations.of(context).downloadStarting,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: config.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;

  const _BadgeConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
  });
}

enum _SemanticToken {
  courseDownloaded,
  courseUpdateAvailable,
  courseNotDownloaded,
  syncPending,
}
