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

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.onFavoriteToggle,
    this.onDownloadTap,
    this.isFavorite = false,
    this.compact = false,
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
                        // Course name
                        Text(
                          course.displayName,
                          style:
                              (compact
                                      ? theme.textTheme.titleSmall
                                      : theme.textTheme.titleMedium)
                                  ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        color: isFavorite
                            ? Colors.red
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
                Row(
                  children: [
                    // Holes
                    _InfoChip(
                      icon: Icons.flag,
                      label: '${course.holesCount} holes',
                    ),

                    if (course.parTotal != null) ...[
                      const SizedBox(width: VspSpacing.sm),
                      _InfoChip(
                        icon: Icons.straighten,
                        label: AppLocalizations.of(context).coursePar('${course.parTotal}'),
                      ),
                    ],

                    if (course.rating != null || course.slope != null) ...[
                      const SizedBox(width: VspSpacing.sm),
                      _InfoChip(
                        icon: Icons.star,
                        label: course.rating != null
                            ? '${course.rating!.toStringAsFixed(1)}'
                            : AppLocalizations.of(context).courseSlope('${course.slope}'),
                        iconColor: Colors.amber,
                      ),
                    ],

                    // Distance (nearby search)
                    if (course.distanceMeters != null) ...[
                      const SizedBox(width: VspSpacing.sm),
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
                  // Verification badge. Reads the effective status, not the
                  // raw one: a VERIFIED stamp on class-D community data is not
                  // a verified course, and this badge is the first thing a
                  // golfer sees about a course they may go and play.
                  VerificationBadge(
                    status:
                        course.dataFreshness?.effectiveVerificationStatus ??
                        VerificationStatus.unverified,
                    compact: compact,
                  ),

                  // Freshness badge
                  FreshnessBadge(
                    dataFreshness: course.dataFreshness,
                    compact: compact,
                  ),

                  // Download state badge — tappable to navigate to download screen
                  InkWell(
                    onTap: onDownloadTap,
                    borderRadius: BorderRadius.circular(16),
                    child: DownloadStateBadge(
                      state: downloadState,
                      compact: compact,
                    ),
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
    final parts = <String>[
      course.displayName,
      '${course.holesCount} holes',
      if (course.parTotal != null) AppLocalizations.of(context).coursePar('${course.parTotal}'),
      if (course.dataFreshness?.isVerified == true) 'verified',
      if (course.dataFreshness?.isStale == true) 'stale data',
    ];
    return parts.join(', ');
  }

  DownloadState _resolveDownloadState() {
    if (course.updateAvailable) {
      return DownloadState.updateAvailable;
    }
    if (course.hasPackage) {
      return DownloadState.downloaded;
    }
    return DownloadState.notDownloaded;
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
