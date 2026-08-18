// Course Card — VSP Mobile App
//
// Card widget showing course name, verification badge, freshness indicator,
// and download state badge.
//
// AC-3: results show verification, data freshness, download, and update state.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_search_result.dart';
import '../../../../domain/models/data_freshness.dart';
import 'download_state_badge.dart';
import 'freshness_badge.dart';
import 'verification_badge.dart';
import 'package:vsp_mobile/domain/services/package_freshness.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';

/// A card displaying course search result with all AC-3 status indicators.
class CourseCard extends StatelessWidget {
  final CourseSearchResult course;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDownloadTap;
  final bool isFavorite;
  final bool compact;

  /// The package version this phone actually holds for this course, or null
  /// where it holds none.
  ///
  /// Supplied by the screen from the device's own manifests, because it is the
  /// only thing that knows. Without it the badge read `hasPackage`, which is
  /// the server saying "there is a package to download" — and rendered it as
  /// "Đã tải". Every course with a package on the server told the golfer it
  /// was already on their phone. That is the one question this badge exists to
  /// answer, asked the night before a round, and it was answering it wrong in
  /// the direction that leaves somebody on a tee with no map.
  final String? downloadedVersion;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.onFavoriteToggle,
    this.onDownloadTap,
    this.isFavorite = false,
    this.compact = false,
      this.downloadedVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine download state
    final downloadState = _resolveDownloadState();

    return Semantics(
      label: _buildSemanticLabel(context),
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? VspSpacing.sm : 12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Top Row: Name + Favorite Button ────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course icon
                  Container(
                    width: compact ? 36 : 44,
                    height: compact ? 36 : 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.golf_course,
                      color: colorScheme.primary,
                      size: compact ? VspIconSize.sm : VspIconSize.md,
                    ),
                  ),
                  const SizedBox(width: VspSpacing.sm),

                  // Course info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The club, because that is what was searched for.
                        Text(
                          course.clubName,
                          style:
                              (compact
                                      ? theme.textTheme.titleSmall
                                      : theme.textTheme.titleMedium)
                                  ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // And which đường of it, where the club has named ones.
                        // Three results reading only "Đường A", "Đường B",
                        // "Đường C" is a search that looks like it failed.
                        if (course.unitName != null) ...[
                          const SizedBox(height: VspSpacing.half),
                          Text(
                            course.unitName!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (!compact && course.address != null) ...[
                          const SizedBox(height: VspSpacing.half),
                          Text(
                            course.address!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Favorite button
                  if (onFavoriteToggle != null)
                    IconButton(
                      onPressed: onFavoriteToggle,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        // From the palette, like every other state colour in
                        // this app. Theme.of(context).colorScheme.error belongs to Material and answers
                        // to no contrast test written here.
                        color: isFavorite
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                      iconSize: compact ? 20 : 24,
                      constraints: BoxConstraints(
                        minWidth: compact ? 36 : 44,
                        minHeight: compact ? 36 : 44,
                      ),
                      tooltip: isFavorite
                          ? AppLocalizations.of(context).courseRemoveFavorite
                          : AppLocalizations.of(context).courseAddFavorite,
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                      size: compact ? 20 : 24,
                    ),
                ],
              ),

              if (!compact) const SizedBox(height: 12),

              if (!compact) ...[
                // ─── Info Row: Holes + Rating/Slope ─────────────────────────
                //
                // Wrap, not Row. Three chips whose widths are translated text
                // and course data, on the screen every round starts from.
                Wrap(
                  spacing: VspSpacing.sm,
                  runSpacing: VspSpacing.xs,
                  children: [
                    // Holes
                    _InfoChip(
                      icon: Icons.flag,
                      // Was the literal '9 holes' — English, on the screen
                      // every golfer starts a round from.
                      label: AppLocalizations.of(context)
                          .roundSetupLayoutHoles(course.holesCount),
                    ),

                    if (course.parTotal != null) ...[
                      _InfoChip(
                        icon: Icons.straighten,
                        label: AppLocalizations.of(context).coursePar('${course.parTotal}'),
                      ),
                    ],

                    if (course.rating != null || course.slope != null) ...[
                      _InfoChip(
                        icon: Icons.star,
                        label: course.rating != null
                            ? '${course.rating!.toStringAsFixed(1)}'
                            : AppLocalizations.of(context).courseSlope('${course.slope}'),
                        iconColor: Theme.of(context).colorScheme.secondary,
                      ),
                    ],

                    // Distance (nearby search)
                    if (course.distanceMeters != null) ...[
                      _InfoChip(
                        icon: Icons.near_me,
                        label: course.formattedDistance(context.distanceUnit),
                        iconColor: colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: VspSpacing.sm),
              ],

              // ─── Badge Row: Verification + Freshness + Download ─────────────
              Wrap(
                spacing: 6,
                runSpacing: VspSpacing.xs,
                children: [
                  // Whether this course can be played offline, first.
                  //
                  // It is the only badge here a golfer can act on, and the
                  // question they are actually asking of a course list at
                  // home the night before. Verification and freshness are
                  // provenance — they qualify the data, they are not a
                  // decision — so they follow it, the same way the weather
                  // panel's source badges moved under the wind reading.
                  InkWell(
                    onTap: onDownloadTap,
                    borderRadius: BorderRadius.circular(16),
                    child: DownloadStateBadge(
                      state: downloadState,
                      compact: compact,
                    ),
                  ),

                  // Then where the data came from. Reads the effective
                  // status, not the raw one: a VERIFIED stamp on class-D
                  // community data is not a verified course.
                  VerificationBadge(
                    status:
                        course.dataFreshness?.effectiveVerificationStatus ??
                        VerificationStatus.unverified,
                    compact: compact,
                  ),

                  FreshnessBadge(
                    dataFreshness: course.dataFreshness,
                    compact: compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSemanticLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Every part translated. A screen reader set to Vietnamese was being read
    // "9 holes, verified, stale data" — the three facts on this card that a
    // sighted golfer gets in their own language.
    final parts = <String>[
      course.displayName,
      l10n.roundSetupLayoutHoles(course.holesCount),
      if (course.parTotal != null) l10n.coursePar('${course.parTotal}'),
      if (course.dataFreshness?.isVerified == true) l10n.verificationVerified,
      if (course.dataFreshness?.isStale == true) l10n.freshnessStale,
    ];
    return parts.join(', ');
  }

  /// What this phone can actually do with this course, tonight.
  ///
  /// Three separate facts, and they used to be two: the server has a package
  /// (`hasPackage`), this phone holds one (`downloadedVersion`), and the two
  /// are the same version. Only the first was consulted, and it was rendered
  /// as "Đã tải".
  DownloadState _resolveDownloadState() {
    final mine = downloadedVersion;
    if (mine == null) {
      // Nothing on this phone. "Tải xuống" whether or not the server has one —
      // the button behind it is the same, and a course with no package says so
      // when it is opened.
      return DownloadState.notDownloaded;
    }
    if (packageIsOutdated(held: mine, latest: course.latestPackageVersion)) {
      return DownloadState.updateAvailable;
    }
    // Held, and current as far as anyone here knows. A server that did not say
    // which version it has is not a reason to nag.
    return DownloadState.downloaded;
  }
}

/// Small info chip for course metadata.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _InfoChip({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor ?? colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
