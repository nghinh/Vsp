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
import 'package:mobile_theme/mobile_theme.dart';

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
    this.readyCourseNames,
  });

  /// What the green banner is claiming is ready — "Đường B", "Đường A + Đường
  /// B".
  ///
  /// The missing branch has named its đường since a two-package round was
  /// first got right. This one did not, and an unnamed success next to a named
  /// failure is what made a download that worked look like a download that did
  /// not: "Sẵn sàng ngoại tuyến" and then, one tap later, "Chưa tải dữ liệu
  /// Đường A".
  ///
  /// Null on a club with one layout, where the name adds nothing.
  final String? readyCourseNames;

  /// The đường of a paired round with their individual states, or empty.
  List<SegmentPackage> get _segments => packageReadiness?.segments ?? const [];

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
          iconColor: Theme.of(context).colorScheme.tertiary, // semantic green
          label: AppLocalizations.of(context).packageOfflineReady,
          subtitle: readyCourseNames,
          backgroundColor: Theme.of(context).colorScheme.tertiary.withOpacity(0.12),
          textColor: Theme.of(context).colorScheme.tertiary,
        );

      case PackageStatus.notDownloaded:
        // Nothing published for this course: nothing to say.
        if (!packageAvailable) {
          return const SizedBox.shrink();
        }
        return _buildBanner(
          context: context,
          icon: Icons.cloud_download_outlined,
          iconColor: Theme.of(context).colorScheme.primary, // semantic amber
          label: missingCourseName == null || missingCourseName!.isEmpty
              ? AppLocalizations.of(context).packageNotDownloaded
              : AppLocalizations.of(context)
                  .packageNotDownloadedNamed(missingCourseName!),
          subtitle: AppLocalizations.of(context).packageNotDownloadedSubtitle,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          textColor: Theme.of(context).colorScheme.primary,
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
          iconColor: Theme.of(context).colorScheme.primary, // semantic amber
          label: AppLocalizations.of(context).packageOutdated,
          subtitle: packageReadiness!.expiresAt != null
              ? AppLocalizations.of(context).packageExpiredOn(
                  _formatDate(context, packageReadiness!.expiresAt!),
                )
              : AppLocalizations.of(context).packageExpired,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          textColor: Theme.of(context).colorScheme.primary,
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
          iconColor: Theme.of(context).colorScheme.error, // semantic red
          label: AppLocalizations.of(context).packageCorrupted,
          subtitle: AppLocalizations.of(context).packageCorruptedSubtitle,
          backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.12),
          textColor: Theme.of(context).colorScheme.error,
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
                  // Both nines of a paired round, side by side.
                  //
                  // The banner could previously describe one đường per visit,
                  // so a golfer who had fetched one of two saw a green banner,
                  // changed the pairing, and saw a red one — with nothing on
                  // screen ever holding the two facts at once. Shown together
                  // the sequence stops being a contradiction and becomes a
                  // list with one item left on it.
                  if (_segments.length > 1) ...[
                    const SizedBox(height: 6),
                    for (final segment in _segments)
                      _SegmentRow(segment: segment, textColor: textColor),
                  ],
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

/// One đường of a paired round: its name and whether its package is here.
///
/// A tick and a cloud rather than two colours, because the difference between
/// "have it" and "need it" is the whole message and colour alone does not
/// carry it for a golfer who cannot distinguish the two — nor for anyone at
/// all in direct sun.
class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.segment, required this.textColor});

  final SegmentPackage segment;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            segment.isReady ? Icons.check_circle : Icons.cloud_download_outlined,
            size: 14,
            color: textColor.withOpacity(segment.isReady ? 0.9 : 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              segment.isReady
                  ? l10n.packageSegmentReady(segment.name)
                  : l10n.packageSegmentMissing(segment.name),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withOpacity(segment.isReady ? 0.9 : 0.7),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
