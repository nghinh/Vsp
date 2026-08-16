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

import 'package:vsp_mobile/core/l10n/relative_time.dart';

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

  /// True when the server actually publishes a package for this course.
  ///
  /// "Not downloaded" is only worth a banner where something can be
  /// downloaded. Most courses in this database have no package at all, and
  /// warning a golfer about the absence of a file they cannot obtain is
  /// noise standing between them and the first tee.
  final bool packageAvailable;

  /// The đường this banner is actually about, where it is one of several.
  ///
  /// A round on Đường A + B needs two packages, and readiness reports them one
  /// at a time. Unnamed, the banner says "Chưa tải dữ liệu sân" before the
  /// first download and says it again, word for word, after that download
  /// succeeded — so the golfer sees a button that appears not to work rather
  /// than a second nine they have not fetched yet.
  ///
  /// Null, or the same as the course already named on screen, leaves the
  /// wording alone: on a course with one layout there is nothing to
  /// disambiguate and "Chưa tải dữ liệu Long Biên Golf Course" is worse than
  /// "Chưa tải dữ liệu sân".
  final String? missingCourseName;

  const PackageStatusBanner({
    super.key,
    this.packageReadiness,
    this.onDownloadPressed,
    this.onWarningAcknowledged,
    this.packageAvailable = false,
    this.missingCourseName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // No readiness yet means no course is selected (or the check is still in
    // flight). There is nothing actionable to show, and a persistent
    // "checking…" banner reads as a stuck state — so render nothing.
    if (packageReadiness == null) {
      return const SizedBox.shrink();
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
        // Nothing published for this course: nothing to say.
        if (!packageAvailable) {
          return const SizedBox.shrink();
        }
        return _buildBanner(
          context: context,
          icon: Icons.cloud_download_outlined,
          iconColor: const Color(0xFFF97316), // semantic amber
          label: missingCourseName == null || missingCourseName!.isEmpty
              ? AppLocalizations.of(context).packageNotDownloaded
              : AppLocalizations.of(context)
                  .packageNotDownloadedNamed(missingCourseName!),
          subtitle: AppLocalizations.of(context).packageNotDownloadedSubtitle,
          backgroundColor: const Color(0xFFF97316).withOpacity(0.12),
          textColor: const Color(0xFFF97316),
          // No "play anyway": starting the round was never blocked on this.
          // The only thing on offer here is the download, which is the whole
          // point of the banner.
          action: onDownloadPressed != null
              ? _Action(
                  label: AppLocalizations.of(context).packageDownload,
                  onPressed: onDownloadPressed!,
                )
              : null,
        );

      case PackageStatus.expired:
        return _buildBanner(
          context: context,
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF97316), // semantic amber
          label: AppLocalizations.of(context).packageOutdated,
          subtitle: packageReadiness!.expiresAt != null
              ? AppLocalizations.of(context).packageExpiredOn(
                  _formatDate(context, packageReadiness!.expiresAt!),
                )
              : AppLocalizations.of(context).packageExpired,
          backgroundColor: const Color(0xFFF97316).withOpacity(0.12),
          textColor: const Color(0xFFF97316),
          action: onWarningAcknowledged != null
              ? _Action(
                  label: AppLocalizations.of(context).packagePlayAnyway,
                  onPressed: onWarningAcknowledged!,
                )
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
              ? _Action(
                  label: AppLocalizations.of(context).packageRedownload,
                  onPressed: onDownloadPressed!,
                )
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

  String _formatDate(BuildContext context, DateTime date) =>
      RelativeTime.format(AppLocalizations.of(context), date);
}

class _Action {
  final String label;
  final VoidCallback onPressed;

  const _Action({required this.label, required this.onPressed});
}
