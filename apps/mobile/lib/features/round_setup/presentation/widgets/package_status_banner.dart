// Package Status Banner — VSP Mobile App
//
// Banner showing package offline readiness status.
// Shows green/amber/red with icon+text based on package status.
//
// Design: ux-spec §4.2, §5.2 — color + icon for offline state, not color-only.
// Touch target: 44pt minimum on interactive elements.
//
// Story 5.1 — Slice B: Round Setup UI Screen

import 'package:flutter/material.dart';

import '../round_setup_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Banner showing package offline readiness status.
///
/// States:
/// - valid: green badge "Offline Ready"
/// - notDownloaded: amber warning "Course data not downloaded"
/// - expired: amber warning "Course data may be outdated"
/// - invalid/checksumMismatch: red warning "Course data is corrupted"
/// - notChecked: neutral "Checking package..."
class PackageStatusBanner extends StatelessWidget {
  final PackageReadiness? packageReadiness;
  final VoidCallback? onDownloadPressed;
  final VoidCallback? onWarningAcknowledged;

  const PackageStatusBanner({
    super.key,
    this.packageReadiness,
    this.onDownloadPressed,
    this.onWarningAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;

    if (packageReadiness == null) {
      return _buildBanner(
        context: context,
        icon: Icons.hourglass_empty,
        iconColor: theme.colorScheme.outline,
        label: AppLocalizations.of(context).packageChecking,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        textColor: theme.colorScheme.onSurfaceVariant,
      );
    }

    switch (packageReadiness!.status) {
      case PackageStatus.valid:
        return _buildBanner(
          context: context,
          icon: Icons.offline_pin,
          iconColor: const Color(0xFF059669), // semantic green
          label: AppLocalizations.of(context).packageOfflineReady,
          backgroundColor: const Color(0xFF059669).withOpacity(0.12),
          textColor: const Color(0xFF059669),
        );

      case PackageStatus.notDownloaded:
        return _buildBanner(
          context: context,
          icon: Icons.cloud_download_outlined,
          iconColor: const Color(0xFFF97316), // semantic amber
          label: AppLocalizations.of(context).packageNotDownloaded,
          subtitle: AppLocalizations.of(context).packageNotDownloadedSubtitle,
          backgroundColor: const Color(0xFFF97316).withOpacity(0.12),
          textColor: const Color(0xFFF97316),
          // "Play Anyway" lets the golfer start the round online without the
          // offline package (scoring only needs holes/par); Download is for
          // offline GPS use.
          secondaryAction: onWarningAcknowledged != null
              ? _Action(label: AppLocalizations.of(context).packagePlayNow, onPressed: onWarningAcknowledged!)
              : null,
          action: onDownloadPressed != null
              ? _Action(label: AppLocalizations.of(context).packageDownload, onPressed: onDownloadPressed!)
              : null,
        );

      case PackageStatus.expired:
        return _buildBanner(
          context: context,
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF97316), // semantic amber
          label: AppLocalizations.of(context).packageOutdated,
          subtitle: packageReadiness!.expiresAt != null
              ? AppLocalizations.of(context).packageExpiredOn(_formatDate(packageReadiness!.expiresAt!))
              : AppLocalizations.of(context).packageExpired,
          backgroundColor: const Color(0xFFF97316).withOpacity(0.12),
          textColor: const Color(0xFFF97316),
          action: onWarningAcknowledged != null
              ? _Action(label: AppLocalizations.of(context).packagePlayAnyway, onPressed: onWarningAcknowledged!)
              : null,
        );

      case PackageStatus.invalid:
        return _buildBanner(
          context: context,
          icon: Icons.error_outline,
          iconColor: const Color(0xFFDC2626), // semantic red
          label: AppLocalizations.of(context).packageCorrupted,
          subtitle: AppLocalizations.of(context).packageCorruptedSubtitle,
          backgroundColor: const Color(0xFFDC2626).withOpacity(0.12),
          textColor: const Color(0xFFDC2626),
          action: onDownloadPressed != null
              ? _Action(label: AppLocalizations.of(context).packageRedownload, onPressed: onDownloadPressed!)
              : null,
        );

      case PackageStatus.notChecked:
        return _buildBanner(
          context: context,
          icon: Icons.hourglass_empty,
          iconColor: theme.colorScheme.outline,
          label: AppLocalizations.of(context).packageChecking,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          textColor: theme.colorScheme.onSurfaceVariant,
        );
    }
  }

  Widget _buildBanner({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    required Color backgroundColor,
    required Color textColor,
    _Action? action,
    _Action? secondaryAction,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),
            if (secondaryAction != null) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: secondaryAction.onPressed,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  secondaryAction.label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: action.onPressed,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 36), // 44pt touch target
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  action.label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _Action {
  final String label;
  final VoidCallback onPressed;

  const _Action({required this.label, required this.onPressed});
}
