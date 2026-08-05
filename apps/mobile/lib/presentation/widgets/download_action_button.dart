// Download Action Button — VSP Mobile App
//
// Primary action button for download states: Download, Update, Pause, Resume, Retry.
// Minimum 44pt touch target per UX spec.
//
// AC-1: retry button; AC-2: update/delete flows.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../domain/models/download_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Action button states for course package download.
enum DownloadAction { download, update, pause, resume, retry, delete }

/// Primary action button for download management.
class DownloadActionButton extends StatelessWidget {
  final DownloadServiceState state;
  final bool wifiRequired;
  final VoidCallback? onDownload;
  final VoidCallback? onUpdate;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const DownloadActionButton({
    super.key,
    required this.state,
    this.wifiRequired = false,
    this.onDownload,
    this.onUpdate,
    this.onPause,
    this.onResume,
    this.onRetry,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final config = _resolveConfig(context);

    return Semantics(
      label: config.semanticLabel,
      button: true,
      enabled: config.enabled,
      child: SizedBox(
        height: VspSpacingSemantic.touchTargetRecommended,
        child: ElevatedButton.icon(
          onPressed: config.enabled ? config.onPressed : null,
          icon: Icon(config.icon, size: VspIconSize.md),
          label: Text(config.label),
          style: ElevatedButton.styleFrom(
            backgroundColor: config.backgroundColor,
            foregroundColor: config.foregroundColor,
            disabledBackgroundColor: config.backgroundColor.withOpacity(0.5),
            disabledForegroundColor: config.foregroundColor.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: VspSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  _ButtonConfig _resolveConfig(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (state) {
      case DownloadServiceState.idle:
        return _ButtonConfig(
          label: AppLocalizations.of(context).downloadDownload,
          icon: Icons.download,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          semanticLabel: AppLocalizations.of(context).downloadLabel,
          enabled: true,
          onPressed: onDownload,
        );

      case DownloadServiceState.fetchingManifest:
      case DownloadServiceState.downloading:
        return _ButtonConfig(
          label: AppLocalizations.of(context).downloadPause,
          icon: Icons.pause,
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurface,
          semanticLabel: AppLocalizations.of(context).downloadPauseLabel,
          enabled: true,
          onPressed: onPause,
        );

      case DownloadServiceState.paused:
        return _ButtonConfig(
          label: AppLocalizations.of(context).downloadResume,
          icon: Icons.play_arrow,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          semanticLabel: AppLocalizations.of(context).downloadResumeLabel,
          enabled: !wifiRequired,
          onPressed: onResume,
        );

      case DownloadServiceState.validating:
        return _ButtonConfig(
          label: AppLocalizations.of(context).downloadValidating,
          icon: Icons.check_circle_outline,
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurfaceVariant,
          semanticLabel: AppLocalizations.of(context).downloadValidatingLabel,
          enabled: false,
          onPressed: null,
        );

      case DownloadServiceState.offlineReady:
        return _ButtonConfig(
          label: AppLocalizations.of(context).downloadUpdate,
          icon: Icons.system_update_alt,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          semanticLabel: AppLocalizations.of(context).downloadUpdateLabel,
          enabled: true,
          onPressed: onUpdate,
        );

      case DownloadServiceState.error:
        return _ButtonConfig(
          label: AppLocalizations.of(context).commonRetry,
          icon: Icons.refresh,
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
          semanticLabel: AppLocalizations.of(context).downloadRetryLabel,
          enabled: true,
          onPressed: onRetry,
        );
    }
  }
}

class _ButtonConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback? onPressed;

  const _ButtonConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.semanticLabel,
    required this.enabled,
    this.onPressed,
  });
}
